# Hermes Eval Pipeline

Bu pipeline Hermes prompt/model kalitesini olcumlemek icin eklendi.

## 1. Dataset Formati

JSONL satiri su alanlari destekler:

- `id` (zorunlu)
- `scope` (`global|bist`)
- `symbol`
- `source`
- `headline`
- `summary`
- `gold_sentiment_label` (opsiyonel)
- `gold_polarity` (opsiyonel)
- `gold_final_score` (opsiyonel)

Ornek: `Scripts/hermes_eval/datasets/sample_gold.jsonl`

Etiketlenecek ham template olusturmak icin:

```bash
python3 Scripts/hermes_eval/build_gold_template.py \
  --symbols AAPL,TSLA,THYAO.IS,SISE.IS \
  --limit 10 \
  --out Scripts/hermes_eval/datasets/gold_template.jsonl
```

## 2. Calistirma

GLM ile:

```bash
export GLM_API_KEY="..."
python3 Scripts/hermes_eval.py \
  --provider glm \
  --dataset Scripts/hermes_eval/datasets/sample_gold.jsonl \
  --task-prompt-file Scripts/hermes_eval/prompts/no_meta_speech_v2.txt
```

Groq ile:

```bash
export GROQ_API_KEY="..."
python3 Scripts/hermes_eval.py \
  --provider groq \
  --dataset Scripts/hermes_eval/datasets/sample_gold.jsonl \
  --task-prompt-file Scripts/hermes_eval/prompts/baseline_v1.txt
```

## 3. Cikti

Her run:

- `Scripts/hermes_eval/out/run_YYYYMMDD_HHMMSS/predictions.jsonl`
- `Scripts/hermes_eval/out/run_YYYYMMDD_HHMMSS/metrics.json`
- `Scripts/hermes_eval/out/run_YYYYMMDD_HHMMSS/report.md`

## 4. Prompt A/B Karsilastirma

Iki run aldiktan sonra:

```bash
python3 Scripts/hermes_eval/compare_runs.py \
  Scripts/hermes_eval/out/run_20260204_200000 \
  Scripts/hermes_eval/out/run_20260204_200300
```

## 5. Hedefler

- `sentiment_accuracy > 0.70`
- `meta_speech_rate < 0.05`
- `polarity_accuracy > 0.75`

Meta-speech: "Hermes soyle dedi", "AI analizi", "LLM sonucu" gibi ifade oranidir.
