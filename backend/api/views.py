import os
import logging
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from dotenv import load_dotenv
from openai import OpenAI

# 環境変数の読み込み
load_dotenv()

# ロギング設定
logger = logging.getLogger(__name__)

# OpenAI API クライアントの初期化
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=OPENAI_API_KEY)

@csrf_exempt
def upload_audio(request):
    """音声ファイルを受け取り、uploads フォルダに保存する"""
    if request.method == 'POST' and request.FILES.get('audio'):
        audio_file = request.FILES['audio']
        file_path = default_storage.save('uploads/' + audio_file.name, ContentFile(audio_file.read()))
        logger.info(f"Audio file saved: {file_path}")

        return JsonResponse({'message': 'Upload successful', 'file_path': file_path})
    
    return JsonResponse({'error': 'Invalid request'}, status=400)


@csrf_exempt
def transcribe_audio(request):
    """Whisper を使って文字起こしを行い、ファイルに保存する"""
    audio_path = "uploads/recorded_audio.webm"
    transcription_path = "uploads/transcription.txt"

    # ファイルが存在するか確認
    if not os.path.exists(audio_path):
        logger.error("Audio file not found.")
        return JsonResponse({'error': 'Audio file not found'}, status=400)

    try:
        with open(audio_path, 'rb') as audio_file:
            logger.debug("Sending request to Whisper API")
            response = client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                response_format="verbose_json",
                timestamp_granularities=["word"]
            )

        # ✅ 修正: `response.text` を直接取得
        transcription_text = response.text

        # 文字起こしをファイルに保存
        with open(transcription_path, "w", encoding="utf-8") as text_file:
            text_file.write(transcription_text)

        logger.info(f"Transcription saved to {transcription_path}")

        return JsonResponse({
            'message': 'Transcription successful',
            'transcription_file': transcription_path
        })

    except Exception as e:
        logger.error(f"Error during transcription: {e}")
        return JsonResponse({'error': str(e)}, status=500)




def split_text(text, max_length=100):
    """全文を保持しつつ、100単語ごとに分割"""
    words = text.split()
    chunks = []
    
    for i in range(0, len(words), max_length):
        chunks.append(" ".join(words[i:i+max_length]))
    
    return chunks

@csrf_exempt
def correct_transcription(request):
    """長い文章を分割し、ChatGPT で添削 + より良い表現を提案"""
    transcription_path = "uploads/transcription.txt"
    corrected_text_path = "uploads/corrected_transcription.txt"

    # 文字起こしファイルが存在するか確認
    if not os.path.exists(transcription_path):
        logger.error("Transcription file not found.")
        return JsonResponse({'error': 'Transcription file not found'}, status=400)

    try:
        # 文字起こし結果を読み込む
        with open(transcription_path, "r", encoding="utf-8") as file:
            transcription_text = file.read()

        # 100単語ごとに分割
        text_chunks = split_text(transcription_text, max_length=100)

        corrected_chunks = []
        for i, chunk in enumerate(text_chunks):
            logger.debug(f"Processing chunk {i+1}/{len(text_chunks)}")

            # 新しいプロンプト: コンテキストを維持しつつ、指定部分のみ添削
            prompt = (
                "You are an advanced AI English tutor specializing in improving the fluency and accuracy of non-native speakers. "
                "You will be provided with a full transcribed text to maintain context, but you should only correct a specific part of it. "
                "Your task is to:\n"
                "1. First, provide a version that only fixes grammar, punctuation, and syntax errors while keeping the meaning intact.\n"
                "2. Second, rewrite the section in a more natural and fluent style that a native speaker would use.\n\n"
                f"Here is the full transcribed text for context:\n{transcription_text}\n\n"
                f"Now, please correct only the following section:\n\n{chunk}\n\n"
                "Format your response like this:\n"
                "**Version 1 (Grammar Fixes):**\n[Corrected text]\n\n"
                "**Version 2 (More Natural Expression):**\n[More fluent version]"
            )

            response = client.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "system", "content": prompt}],
                temperature=0.7
            )

            corrected_chunks.append(f"\n=== Section {i+1} ===\n{response.choices[0].message.content}")

        # 添削結果をファイルに保存
        corrected_text = "\n".join(corrected_chunks)
        with open(corrected_text_path, "w", encoding="utf-8") as file:
            file.write(corrected_text)

        logger.info(f"Corrected transcription saved to {corrected_text_path}")

        return JsonResponse({
            'message': 'Correction successful',
            'corrected_text_file': corrected_text_path
        })

    except Exception as e:
        logger.error(f"Error during correction: {e}")
        return JsonResponse({'error': str(e)}, status=500)
