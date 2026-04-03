from collections import deque
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from tensorflow.keras.models import load_model
import pickle
from flask import Flask, jsonify, request
from flask_cors import CORS


with open('actions.pkl', 'rb') as f:
    actions = pickle.load(f)

model = load_model('action.h5')

base_options = python.BaseOptions(model_asset_path='hand_landmarker.task')
options = vision.HandLandmarkerOptions(base_options=base_options, num_hands=1)
detector = vision.HandLandmarker.create_from_options(options)

sequence = deque(maxlen=30)
predictions = []
sentence = []
threshold = 0.45

app = Flask(__name__)
CORS(app)


@app.get('/health')
def health():
    return jsonify({
        'status': 'ok',
        'actions': list(actions),
    })


@app.post('/predict')
def predict():
    if 'frame' not in request.files:
        return jsonify({'error': 'Missing frame file'}), 400

    frame_file = request.files['frame']
    frame_bytes = np.frombuffer(frame_file.read(), np.uint8)
    frame = cv2.imdecode(frame_bytes, cv2.IMREAD_COLOR)

    if frame is None:
        return jsonify({'error': 'Invalid frame image'}), 400

    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
    results = detector.detect(mp_image)

    hand_detected = bool(results.hand_landmarks)
    landmarks = []

    output_word = sentence[-1] if sentence else '--'
    output_confidence = 0.0
    status = 'No hand detected. Show one hand to camera.'

    if hand_detected:
        temp_coords = []
        for landmark in results.hand_landmarks[0]:
            temp_coords.extend([landmark.x, landmark.y, landmark.z])
            landmarks.append({
                'x': float(landmark.x),
                'y': float(landmark.y),
            })

        keypoints = np.array(temp_coords)
        sequence.append(keypoints)
        status = 'Collecting frames...'

    if len(sequence) == 30:
        res = model.predict(np.expand_dims(sequence, axis=0), verbose=0)[0]
        predicted_idx = int(np.argmax(res))
        top_word = actions[predicted_idx]
        top_confidence = float(res[predicted_idx])
        predictions.append(predicted_idx)

        output_word = top_word
        output_confidence = top_confidence
        status = 'Detecting...'

        if len(predictions) >= 8 and np.unique(predictions[-8:])[0] == predicted_idx:
            if top_confidence > threshold:
                word = top_word

                if sentence:
                    if word != sentence[-1]:
                        sentence.append(word)
                else:
                    sentence.append(word)

                if len(sentence) > 5:
                    sentence[:] = sentence[-5:]

                output_word = word
                output_confidence = top_confidence
                status = 'Stable detection'

        if sentence and output_word == '--':
            output_word = sentence[-1]

    return jsonify({
        'word': output_word,
        'confidence': output_confidence,
        'status': status,
        'hand_detected': hand_detected,
        'landmarks': landmarks,
        'sentence': sentence,
    })


if __name__ == '__main__':
    print('Starting SignSpeaks web API on http://127.0.0.1:8000')
    app.run(host='127.0.0.1', port=8000, debug=False)
