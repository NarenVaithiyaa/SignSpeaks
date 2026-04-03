import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from tensorflow.keras.models import load_model
import pickle
from collections import deque


def emit_detection(word, confidence):
    print(f"DETECTION|word={word}|confidence={confidence:.4f}", flush=True)

# 1. Load the labels and the trained LSTM model
with open('actions.pkl', 'rb') as f:
    actions = pickle.load(f)
model = load_model('action.h5')

# 2. Setup MediaPipe Tasks API
base_options = python.BaseOptions(model_asset_path='hand_landmarker.task')
options = vision.HandLandmarkerOptions(base_options=base_options, num_hands=1)
detector = vision.HandLandmarker.create_from_options(options)

# 3. State variables
sequence = deque(maxlen=30) # Buffer to hold the last 30 frames
sentence = []
predictions = []
threshold = 0.7 # Confidence threshold (0.0 to 1.0)

cap = cv2.VideoCapture(0) # Standard Windows camera index

print(f"Model ready. Detecting: {actions}")
print("Press 'q' to quit, 'c' to clear sentence.")
print("STATUS|ready", flush=True)

while cap.isOpened():
    ret, frame = cap.read()
    if not ret: break

    frame = cv2.flip(frame, 1) # Mirror view
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
    
    results = detector.detect(mp_image)
    
    # Extract landmarks for current frame
    keypoints = np.zeros(63)
    if results.hand_landmarks:
        for hand_landmarks in results.hand_landmarks:
            temp_coords = []
            for landmark in hand_landmarks:
                temp_coords.extend([landmark.x, landmark.y, landmark.z])
                
                # Draw skeleton tracking
                cx, cy = int(landmark.x * frame.shape[1]), int(landmark.y * frame.shape[0])
                cv2.circle(frame, (cx, cy), 3, (0, 255, 0), -1)
            keypoints = np.array(temp_coords)

    # Add frame to our rolling 30-frame sequence
    sequence.append(keypoints)

    # Only predict once the buffer is full (30 frames)
    if len(sequence) == 30:
        res = model.predict(np.expand_dims(sequence, axis=0), verbose=0)[0]
        predicted_idx = np.argmax(res)
        predictions.append(predicted_idx)
        
        # Stability check: Ensure the last 15 frames predicted the same word
        if len(predictions) > 15 and np.unique(predictions[-15:])[0] == predicted_idx:
            if res[predicted_idx] > threshold:
                word = actions[predicted_idx]
                confidence = float(res[predicted_idx])
                
                if len(sentence) > 0:
                    if word != sentence[-1]:
                        sentence.append(word)
                        emit_detection(word, confidence)
                else:
                    sentence.append(word)
                    emit_detection(word, confidence)

        if len(sentence) > 5: # Keep text on screen manageable
            sentence = sentence[-5:]

    # Visual Feedback
    cv2.rectangle(frame, (0,0), (640, 40), (245, 117, 16), -1)
    cv2.putText(frame, ' '.join(sentence), (3,30), 
                cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2, cv2.LINE_AA)

    cv2.imshow('Sign Speaks - LSTM Words', frame)

    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'): break
    if key == ord('c'):
        sentence = []
        print("STATUS|cleared", flush=True)

cap.release()
cv2.destroyAllWindows()
print("STATUS|stopped", flush=True)