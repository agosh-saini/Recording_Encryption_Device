#!/usr/bin/env python3
"""
Physical Button Video Recorder with Real-time MP4 conversion
Records video while simultaneously converting to MP4 format

CONCEPTUAL SECURITY NOTE:
In a production system, you would want to encrypt recordings for security.
The encryption step would typically happen after MP4 conversion:
1. Camera captures raw H.264 stream
2. FFmpeg converts to MP4 format
3. GPG (or similar) encrypts the MP4 file using public-key cryptography
4. Encrypted file is stored, ensuring only authorized parties can decrypt it

This ensures that even if the storage device is compromised, the video content
remains protected. The encryption would use algorithms like AES-256 for symmetric
encryption, wrapped with RSA/ECC public keys for key exchange.
"""

import RPi.GPIO as GPIO
import subprocess
import time
import os
import signal
import sys
from datetime import datetime
from zoneinfo import ZoneInfo
import threading


# GPIO Configuration
BUTTON_PIN = 15  # GPIO 15 (Physical Pin 10)
LED_PIN = 17     # GPIO 17 (Physical Pin 11)

# Configuration
ASSETS_DIR = os.path.expanduser("~/assets")
ENCRYPTION_ACTIVE = False
START_COOLDOWN = 5
CHUNK_SIZE = 65536  # 64KB chunks for streaming


class StreamingRecorder:
    def __init__(self):
        self.recording_active = False
        self.processes = {}
        self.output_file = None
        self.temp_fifo = None
        
    def create_named_pipe(self, folder_path):
        """Create a named pipe for streaming data between processes"""
        pipe_path = os.path.join(folder_path, "video_stream")
        try:
            if os.path.exists(pipe_path):
                os.remove(pipe_path)
            os.mkfifo(pipe_path)
            return pipe_path
        except Exception as e:
            print(f"❌ Error creating named pipe: {e}")
            return None
    
    def start_camera_capture(self, pipe_path):
        """Start camera capture and stream to named pipe"""
        print("📹 Starting camera capture...")
        print(f"🔍 Camera pipe path: {pipe_path}")
        
        # rpicam-vid outputs to stdout, which we'll pipe to our named pipe
        camera_cmd = [
            "rpicam-vid",
            "-o", "-",  # Output to stdout
            "--width", "1920",
            "--height", "1080", 
            "--framerate", "10",         # 10 fps for speed
            "--timeout", "0",            # No timeout
            "--inline",                  # Ensure inline encoding
            "--flush",  # Ensure immediate flushing
            "--codec", "h264",      # Ensure hardware encoding
            "--awb", "auto",  # White balance mode (Auto)
   
        ]
        
        print(f"🔍 Camera command: {' '.join(camera_cmd)}")
        
        camera_process = subprocess.Popen(
            camera_cmd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            bufsize=0
        )
        
        # Start a thread to copy camera output to named pipe
        def stream_to_pipe():
            bytes_written = 0
            chunk_count = 0
            try:
                print(f"🔍 Opening pipe for writing: {pipe_path}")
                with open(pipe_path, 'wb') as pipe_out:
                    print("✅ Pipe opened successfully, starting data stream...")
                    while self.recording_active and camera_process.poll() is None:
                        data = camera_process.stdout.read(CHUNK_SIZE)
                        if data:
                            pipe_out.write(data)
                            pipe_out.flush()
                            bytes_written += len(data)
                            chunk_count += 1
                            if chunk_count % 100 == 0:  # Log every 100 chunks
                                print(f"📊 Streamed {bytes_written / (1024*1024):.1f} MB ({chunk_count} chunks)")
                        else:
                            time.sleep(0.001)
                print(f"📊 Total bytes streamed: {bytes_written / (1024*1024):.1f} MB ({chunk_count} chunks)")
            except Exception as e:
                print(f"⚠️ Stream to pipe error: {e}")
                print(f"📊 Bytes written before error: {bytes_written / (1024*1024):.1f} MB")
        
        threading.Thread(target=stream_to_pipe, daemon=True).start()
        return camera_process
    
    def start_ffmpeg_conversion(self, pipe_path, output_path):
        """Start FFmpeg to convert H.264 stream to MP4 in real-time"""
        print("🔄 Starting real-time MP4 conversion...")
        
        # Create another named pipe for FFmpeg output to encryption
        # CONCEPTUAL: In a secure system, this pipe would feed into GPG encryption
        mp4_pipe = os.path.join(os.path.dirname(pipe_path), "mp4_stream")
        try:
            if os.path.exists(mp4_pipe):
                os.remove(mp4_pipe)
            os.mkfifo(mp4_pipe)
        except Exception as e:
            print(f"❌ Error creating MP4 pipe: {e}")
            return None, None
        
        # FFmpeg process: H.264 input -> MP4 output to pipe
        # CONCEPTUAL: In secure version, this pipe feeds GPG encryption process
        ffmpeg_process = subprocess.Popen([
            "ffmpeg",
            "-f", "h264",           # Input format
            "-i", pipe_path,        # Input from camera pipe
            "-c", "copy",      # Re-encode with H.264 for compression
            "-f", "mp4",            # Output format
            "-movflags", "frag_keyframe+empty_moov+faststart",  # Enable streaming
            "-reset_timestamps", "1",
            "-y",                   # Overwrite output
            mp4_pipe               # Output to MP4 pipe (would feed encryption)
        ], stdin=subprocess.PIPE, stderr=subprocess.PIPE)
        
        return ffmpeg_process, mp4_pipe
    
    def start_gpg_encryption(self, mp4_pipe, encrypted_output):
        """
        CONCEPTUAL: Start GPG encryption of the MP4 stream
        
        In a secure implementation, this would:
        1. Read MP4 data from the pipe in real-time
        2. Encrypt using recipient's public key (e.g., "mlink@trymlink.com")
        3. Use AES-256 for symmetric encryption (fast)
        4. Compress before encryption to reduce size
        5. Write encrypted output to .gpg file
        
        Example GPG command (conceptual):
        gpg --encrypt \\
            --recipient "mlink@trymlink.com" \\
            --output recording.mp4.gpg \\
            --cipher-algo AES256 \\
            --compress-algo 1 \\
            recording.mp4
        
        This ensures:
        - Only authorized parties with private key can decrypt
        - Data is encrypted before hitting disk
        - Even if device is compromised, videos remain protected
        """
        print("🔐 CONCEPTUAL: Starting real-time encryption...")
        print("💡 In a secure system, GPG would encrypt the MP4 stream here")
        print("   Command would be: gpg --encrypt --recipient mlink@trymlink.com")
        print("   Using AES-256 cipher and compression for efficiency")
        
        # CONCEPTUAL: In actual implementation, this would spawn GPG process:
        # gpg_process = subprocess.Popen([
        #     "gpg",
        #     "--encrypt",
        #     "--recipient", "mlink@trymlink.com",
        #     "--output", encrypted_output,
        #     "--cipher-algo", "AES256",
        #     "--compress-algo", "1",
        #     mp4_pipe
        # ], stderr=subprocess.PIPE)
        # return gpg_process
        
        # For now, just copy MP4 pipe to output (simulating encryption conceptually)
        # In secure version, GPG would handle this encryption
        print(f"💡 Conceptually encrypting {mp4_pipe} -> {encrypted_output}")
        return None  # No actual process spawned
    
    def start_streaming_recording(self, folder_path):
        """Start the complete streaming pipeline"""
        global ENCRYPTION_ACTIVE
        
        self.recording_active = True
        timestamp = datetime.now(ZoneInfo('America/New_York')).strftime('%Y-%m-%d_%HH-%MM-%SS')
        # CONCEPTUAL: In secure version, this would be .mp4.gpg (encrypted)
        encrypted_output = os.path.join(folder_path, f"recording_{timestamp}.mp4")
        
        try:
            # Create named pipe for camera -> FFmpeg
            camera_pipe = self.create_named_pipe(folder_path)
            if not camera_pipe:
                return False
                
            # Start camera capture
            camera_process = self.start_camera_capture(camera_pipe)
            self.processes['camera'] = camera_process
            
            # Small delay to ensure camera starts
            time.sleep(0.5)
            
            # Start FFmpeg conversion
            ffmpeg_process, mp4_pipe = self.start_ffmpeg_conversion(camera_pipe, encrypted_output)
            if not ffmpeg_process:
                return False
            self.processes['ffmpeg'] = ffmpeg_process
            
            # Small delay to ensure FFmpeg starts
            time.sleep(0.5)
            
            # CONCEPTUAL: Start GPG encryption
            # In secure version, this would spawn actual GPG process
            gpg_process = self.start_gpg_encryption(mp4_pipe, encrypted_output)
            # For now, we'll write MP4 directly (conceptually simulating encryption)
            if gpg_process:
                self.processes['gpg'] = gpg_process
            else:
                # Fallback: copy MP4 pipe to output file (conceptual - no actual encryption)
                def copy_mp4_to_output():
                    try:
                        with open(mp4_pipe, 'rb') as pipe_in, open(encrypted_output, 'wb') as out_file:
                            while self.recording_active:
                                data = pipe_in.read(CHUNK_SIZE)
                                if not data:
                                    break
                                out_file.write(data)
                                out_file.flush()
                    except Exception as e:
                        print(f"⚠️ Error copying MP4 stream: {e}")
                
                threading.Thread(target=copy_mp4_to_output, daemon=True).start()
            
            self.output_file = encrypted_output
            
            # Start encryption LED indicator
            ENCRYPTION_ACTIVE = True
            encryption_thread = threading.Thread(target=blink_led_recording)
            encryption_thread.daemon = True
            encryption_thread.start()
            
            print(f"✅ Streaming pipeline started - recording to: {encrypted_output}")
            return True
            
        except Exception as e:
            print(f"❌ Error starting streaming pipeline: {e}")
            self.stop_streaming_recording()
            return False
    
    def stop_streaming_recording(self):
        """Stop the streaming pipeline gracefully"""
        global ENCRYPTION_ACTIVE
        
        print("⏹️ Stopping streaming pipeline...")
        self.recording_active = False
        ENCRYPTION_ACTIVE = False
        
        # Stop processes in reverse order: camera -> ffmpeg -> gpg
        for process_name in ['camera', 'ffmpeg', 'gpg']:
            if process_name in self.processes:
                process = self.processes[process_name]
                try:
                    if process and process.poll() is None:
                        print(f"🛑 Stopping {process_name} process...")
                        
                        # For camera, send SIGTERM first
                        if process_name == 'camera':
                            process.terminate()
                            time.sleep(1)
                        
                        # For FFmpeg and GPG, close stdin to signal end
                        if process_name in ['ffmpeg', 'gpg'] and process.stdin:
                            try:
                                process.stdin.close()
                            except:
                                pass
                        
                        # Wait for graceful shutdown
                        try:
                            process.wait(timeout=5)
                            print(f"✅ {process_name} stopped gracefully")
                        except subprocess.TimeoutExpired:
                            print(f"🔄 Force killing {process_name}...")
                            process.kill()
                            process.wait()
                            
                except Exception as e:
                    print(f"⚠️ Error stopping {process_name}: {e}")
        
        # Clean up named pipes
        try:
            folder_path = os.path.dirname(self.output_file) if self.output_file else None
            if folder_path:
                for pipe_name in ["video_stream", "mp4_stream"]:
                    pipe_path = os.path.join(folder_path, pipe_name)
                    if os.path.exists(pipe_path):
                        os.remove(pipe_path)
        except Exception as e:
            print(f"⚠️ Error cleaning up pipes: {e}")
        
        # Check final output
        if self.output_file and os.path.exists(self.output_file):
            file_size = os.path.getsize(self.output_file)
            if file_size > 0:
                print(f"✅ Recording complete: {self.output_file}")
                print(f"📊 File size: {file_size / (1024*1024):.1f} MB")
                print("💡 CONCEPTUAL: In secure system, this would be encrypted (.mp4.gpg)")
            else:
                print("⚠️ Output file is empty - recording may have failed")
        else:
            print("❌ No output file created")
        
        # Reset state
        self.processes.clear()
        self.output_file = None
        GPIO.output(LED_PIN, GPIO.LOW)

# Global streaming recorder instance
recorder = StreamingRecorder()

def setup_gpio():
    """Setup GPIO pins"""
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    GPIO.setup(LED_PIN, GPIO.OUT)
    GPIO.output(LED_PIN, GPIO.LOW)

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    print("\n⏹️ Shutting down...")
    if recorder.recording_active:
        recorder.stop_streaming_recording()
    GPIO.cleanup()
    sys.exit(0)

def blink_led_recording():
    """Blink LED to indicate active recording and encryption"""
    global ENCRYPTION_ACTIVE
    while ENCRYPTION_ACTIVE:
        GPIO.output(LED_PIN, GPIO.HIGH)
        time.sleep(0.3)
        GPIO.output(LED_PIN, GPIO.LOW)
        time.sleep(0.3)

def blink_led_cooldown(cooldown_until):
    """Blink LED slowly during cooldown period"""
    while time.time() < cooldown_until:
        GPIO.output(LED_PIN, GPIO.HIGH)
        time.sleep(0.5)
        GPIO.output(LED_PIN, GPIO.LOW)
        time.sleep(0.5)

def start_cooldown_blink(cooldown_until):
    """Start LED blinking for cooldown period"""
    cooldown_thread = threading.Thread(target=blink_led_cooldown, args=(cooldown_until,))
    cooldown_thread.daemon = True
    cooldown_thread.start()

def check_gpg_key():
    """
    CONCEPTUAL: Check if the GPG key is available and trusted
    
    In a secure implementation, this would:
    1. Check if recipient's public key exists in GPG keyring
    2. Verify key is trusted
    3. Ensure key is valid for encryption
    
    Example command (conceptual):
    gpg --list-keys "mlink@trymlink.com"
    
    This ensures encryption can proceed with valid recipient key.
    """
    print("💡 CONCEPTUAL: Checking GPG key availability...")
    print("   In secure system, would verify: gpg --list-keys mlink@trymlink.com")
    print("   Key would need to be imported and trusted for encryption")
    return True  # Conceptually always available

def create_recording_folder():
    """Create a new folder for this recording session"""
    timestamp = datetime.now(ZoneInfo('America/New_York')).strftime('%Y-%m-%d_%HH-%MM-%SS')
    folder_name = f"recording_{timestamp}"
    folder_path = os.path.join(ASSETS_DIR, folder_name)
    
    os.makedirs(folder_path, exist_ok=True)
    print(f"📁 Created recording folder: {folder_path}")
    
    return folder_path

def main():
    """Main recording loop"""
    print("🚀 Starting Real-time Streaming Video Recorder with Live Encryption")
    print(f"📁 Assets directory: {ASSETS_DIR}")
    print("🔑 CONCEPTUAL: Checking GPG key availability...")
    
    # Check dependencies
    required_commands = ['rpicam-vid', 'ffmpeg']
    missing_commands = []
    
    for cmd in required_commands:
        try:
            subprocess.run([cmd, "--version"], capture_output=True, timeout=5)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            missing_commands.append(cmd)
    
    if missing_commands:
        print(f"❌ Missing required commands: {', '.join(missing_commands)}")
        return
    
    # CONCEPTUAL: Check if GPG key is available
    if not check_gpg_key():
        print("❌ CONCEPTUAL: GPG key not found. In secure system, would need:")
        print("   gpg --import ~/mlink_public.asc")
        print("   gpg --edit-key <key_id> trust")
        return
    
    print("✅ All dependencies ready")
    print("🎬 Real-time streaming mode: MP4 conversion and encryption happen during recording")
    print("💡 CONCEPTUAL: Encryption step uses GPG with recipient's public key")
    print("🔘 Press button to start streaming recording")
    print("🔘 Press button again to stop and finalize encrypted file")
    print(f"⏰ {START_COOLDOWN} second cooldown after starting recording")
    print("⏹️ Press Ctrl+C to exit")
    
    # Ensure assets directory exists
    os.makedirs(ASSETS_DIR, exist_ok=True)
    
    # Setup signal handler for Ctrl+C
    signal.signal(signal.SIGINT, signal_handler)
    
    setup_gpio()
    
    button_press_time = None
    start_cooldown_until = 0
    
    try:
        while True:
            button_state = GPIO.input(BUTTON_PIN)
            
            if button_state == GPIO.LOW:  # Button pressed
                if button_press_time is None:
                    button_press_time = time.time()
                    
            elif button_state == GPIO.HIGH and button_press_time is not None:
                # Button released
                press_duration = time.time() - button_press_time
                current_time = time.time()
                
                if press_duration < 0.5:  # Short press (debounce)
                    if not recorder.recording_active:
                        # Check cooldown
                        if current_time < start_cooldown_until:
                            remaining_cooldown = start_cooldown_until - current_time
                            print(f"⏰ Cooldown active - wait {remaining_cooldown:.1f} more seconds")
                        else:
                            # Start streaming recording
                            print("🔘 Button pressed - starting real-time recording...")
                            folder = create_recording_folder()
                            
                            if recorder.start_streaming_recording(folder):
                                # Set cooldown period
                                start_cooldown_until = current_time + START_COOLDOWN
                                print(f"⏰ {START_COOLDOWN} second cooldown started")
                                start_cooldown_blink(start_cooldown_until)
                            else:
                                print("❌ Failed to start streaming recording")
                    else:
                        # Stop streaming recording
                        print("🔘 Button pressed - stopping and finalizing...")
                        recorder.stop_streaming_recording()
                
                button_press_time = None
                time.sleep(0.2)  # Debounce delay
            
            time.sleep(0.01)  # Small delay to prevent CPU hogging
            
    except KeyboardInterrupt:
        pass
    finally:
        if recorder.recording_active:
            recorder.stop_streaming_recording()
        GPIO.cleanup()
        print("✅ GPIO cleanup complete")

if __name__ == "__main__":
    main()