from django.urls import path
from .views import upload_audio, transcribe_audio, correct_transcription

urlpatterns = [

    path('upload/', upload_audio, name = "upload_audio"),
    path('transcribe/', transcribe_audio, name = "transcribe_audio"),
    path('correct/', correct_transcription, name = "correct_transcription"),
]