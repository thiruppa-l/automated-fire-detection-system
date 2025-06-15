# Automated Fire Detection System 🔥

This project detects fire automatically using IR sensors (hardware) or image processing (software), and provides alerts for safety.

## 🔧 Tech Used
- ESP8266 + IR sensors (Hardware)
- Python (OpenCV for video-based fire detection)
- Flutter (optional app alert system)

## 📁 Structure
- `esp_code/`: Detects flame/smoke via IR and sends alerts
- `python_code/`: Detects fire via image processing
- `flutter_app/`: Mobile notification interface

## ⚙️ How it Works
- ESP8266 continuously checks sensor input
- Python script optionally detects fire from video stream
- Alerts are sent to Flutter app for quick response

## 🚨 Disclaimer
Prototype only. Not a replacement for certified fire alarms.
