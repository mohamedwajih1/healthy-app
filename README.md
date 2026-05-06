# Healthy Habits App 🤖

Flutter app with AI-powered habit analysis backend.

## Project Structure

```
├── lib/                    # Flutter app
├── ai_backend/             # Python AI server
│   ├── server_updated.py   # Flask API
│   ├── behavioral_ai_fixed_clean.py  # AI engine
│   ├── train_model.py      # Model training
│   ├── requirements.txt    # Python deps
│   └── *.pkl               # Trained models
```

## Getting Started

### 1. Run AI Backend
```bash
cd ai_backend
pip install -r requirements.txt
python server_updated.py
```

### 2. Run Flutter App
```bash
flutter run
```

## AI Features
- Smart habit suggestions based on user behavior
- Dynamic motivation messages
- Performance analysis & insights
- Adaptive recommendation engine
