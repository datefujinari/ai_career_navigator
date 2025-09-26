# 最小のHTTP関数。GitHub公開情報を取得 → Vertex AI Geminiで学習ロードマップ文章を生成。
# デプロイはCloud Run functionsのHTTPとして行います。

import os
import json
import requests
from flask import Request, make_response
import vertexai
from vertexai.generative_models import GenerativeModel

PROJECT_ID = os.environ.get("GCP_PROJECT") or os.environ.get("GOOGLE_CLOUD_PROJECT")
LOCATION = os.environ.get("LOCATION", "us-central1")  # 任意の対応リージョン

# -------------------------------
# GitHubの公開情報取得（MVP用に簡易）
# -------------------------------
def fetch_github_summary(username: str) -> dict:
    # /users/{user} と /users/{user}/repos を使う（公開情報のみ）
    # 公式RESTドキュメント参照
    user = requests.get(f"https://api.github.com/users/{username}", timeout=20).json()
    repos = requests.get(f"https://api.github.com/users/{username}/repos?per_page=100", timeout=20).json()

    langs = {}
    stars = 0
    for r in repos if isinstance(repos, list) else []:
        stars += r.get("stargazers_count", 0)
        lang = r.get("language")
        if lang:
            langs[lang] = langs.get(lang, 0) + 1

    return {
        "login": user.get("login"),
        "name": user.get("name"),
        "public_repos": user.get("public_repos"),
        "followers": user.get("followers"),
        "top_languages": sorted(langs.items(), key=lambda x: x[1], reverse=True)[:5],
        "total_repo_stars": stars,
    }

# -------------------------------
# HTTPエントリポイント
# -------------------------------
def analyze(request: Request):
    if request.method == "OPTIONS":
        # CORSプリフライト（必要なら）
        resp = make_response("", 204)
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
        resp.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        return resp

    data = request.get_json(silent=True) or {}
    user = (data.get("user") or "").strip()
    target = (data.get("target") or "").strip()
    if not user or not target:
        return _json({"error": "user/target is required"}, 400)

    # 1) GitHub公開情報（あなた）
    me_info = fetch_github_summary(user)

    # 2) 目標がGitHubユーザー名っぽければ軽く要約（英数字と-/_の単純判定）
    target_info = {}
    if all(c.isalnum() or c in "-_" for c in target):
        try:
            target_info = fetch_github_summary(target)
        except Exception:
            target_info = {"note": "target GitHub lookup failed (ignored in MVP)"}

    # 3) Vertex AI 初期化
    vertexai.init(project=PROJECT_ID, location=LOCATION)
    model = GenerativeModel("gemini-1.5-pro")  # 安定版モデルを利用

    prompt = f"""
あなたはキャリアコーチです。
以下の現在地(自分)と目標の情報を元に、ギャップを簡潔に特定し、
学習ロードマップを5〜8個の実行可能な箇条書きで提案してください。
各項目は「目的：/ アクション：/ 目安時間：/ 参考キーワード：」を含めてください。

[自分のGitHub要約]
{json.dumps(me_info, ensure_ascii=False)}

[目標のヒント（ユーザー or キーワード）]
{target}
[目標のGitHub要約（あれば）]
{json.dumps(target_info, ensure_ascii=False)}
"""
    result = model.generate_content(prompt)
    text = result.text or "提案を生成できませんでした"

    # テキストを行に割る（フロントは配列を想定）
    lines = [ln.strip(" -•\t") for ln in text.splitlines() if ln.strip()]
    return _json({"roadmap": lines[:12]})  # 上限を軽く

def _json(obj, code=200):
    resp = make_response(json.dumps(obj, ensure_ascii=False), code)
    resp.headers["Content-Type"] = "application/json; charset=utf-8"
    resp.headers["Access-Control-Allow-Origin"] = "*"
    return resp
