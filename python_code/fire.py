import cv2
import torch
import firebase_admin
from firebase_admin import credentials, db
import time
import threading

# Global variable to hold the current person count and a lock for thread safety.
current_count = 0
count_lock = threading.Lock()

def firebase_updater(detected_ref):
    global current_count
    while True:
        with count_lock:
            count_val = current_count
        # Update Firebase with the current count
        detected_ref.set(count_val)
        # Wait for 1 second before updating again
        time.sleep(0.5)

def main():
    global current_count
    
    # Initialize Firebase
    cred = credentials.Certificate("key.json")
    firebase_admin.initialize_app(cred, {
        'databaseURL': 'https://firedection-a6dbe-default-rtdb.firebaseio.com/'
    })
    
    # Create a reference for the detected humans count in Firebase
    detected_ref = db.reference('fire_alarm/detectedHumans')
    
    # Start the Firebase updater thread (daemon so it exits when the main thread does)
    updater_thread = threading.Thread(target=firebase_updater, args=(detected_ref,), daemon=True)
    updater_thread.start()
    
    # Load the YOLOv5 model (using yolov5l for this example; you can use yolov5n for a lightweight model)
    model = torch.hub.load('ultralytics/yolov5', 'yolov5x', pretrained=True)
    model.eval()  # Set model to evaluation mode
    
    # Open the webcam (device 0 is the default webcam)
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Could not open webcam.")
        return
    
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame")
            break
        
        # Run YOLOv5 detection on the current frame
        results = model(frame)
        
        # Filter detections to only include persons (class 0 in COCO) with confidence > 0.35
        if results.pred:
            pred_tensor = results.pred[0]
            person_tensor = pred_tensor[(pred_tensor[:, 5] == 0) & (pred_tensor[:, 4] > 0.35)]
            count = person_tensor.shape[0]
            results.pred[0] = person_tensor
        else:
            count = 0
        
        # Update the global count variable safely
        with count_lock:
            current_count = count
        
        print("Number of persons detected:", count)
        
        # Render the results on the frame and make a writable copy
        annotated_frame = results.render()[0].copy()
        
        # Overlay the count on the frame
        cv2.putText(annotated_frame, f"Persons: {count}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2, cv2.LINE_AA)
        
        # Display the annotated frame
        cv2.imshow("YOLOv5 Webcam Detection", annotated_frame)
        
        # Exit if 'q' is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    # Release resources
    cap.release()
    cv2.destroyAllWindows()

if __name__ == '__main__':
    main()
