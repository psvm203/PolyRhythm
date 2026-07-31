# level-generator

WAV → Godot `level_data.tres` 자동 생성 도구.

## 알고리즘

1. librosa로 BPM 검출
2. STFT → 주파수 대역별 energy envelope
3. 비트 그리드 슬롯(기본 1 polygon = 1 beat)별 평균 에너지 계산
4. min-max 정규화 → `[min_sides, max_sides]` 로 양자화
5. 시작/끝 트라이앵글 강제, 인접 polygon 변이 같지 않도록 후처리
6. `seconds_per_edge = (60 / bpm) / edges_per_beat` 로 Godot 레벨 생성

## 설치

```bash
cd tools/level_generator
uv sync --extra viz --extra dev
```

## 사용

```bash
uv run python -m level_generator <wav> \
  --output ../../level/data/level_data.tres \
  --bpm-hint 121.9 \
  --band combined \
  --edges-per-beat 4 \
  --max-sides 8 \
  --preview ../../preview.png \
  --report ../../build_report.json
```

### 주요 옵션

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `--bpm-hint` | 자동 검출 | 알려진 BPM 입력 시 정확도↑ |
| `--band` | `combined` | `low` / `mid` / `high` / `combined` |
| `--edges-per-beat` | 4 | 다각형 1 beat 내 edge 수 (16분음표) |
| `--beats-per-polygon` | 1 | 다각형 하나가 차지하는 beat 수 |
| `--min-sides` / `--max-sides` | 3 / 8 | vertex count 범위 |
| `--smooth-ms` | 50 | envelope smoothing 윈도우 (ms) |
| `--sequence-smooth` | 3 | 매듭 polygon에 적용할 median filter 크기 |
| `--preview` | - | 미리보기 PNG 경로 |
| `--report` | - | JSON 빌드 보고서 경로 |

## Godot 통합

생성된 `level_data.tres`만으로도 동작합니다. `level/level.tscn`이 자동으로 로드하고 WAV를 autoplay합니다.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .     # 에디터 실행
# 또는 /Applications/Godot.app/Contents/MacOS/Godot --path . --headless --quit-after 60
```

## 개발

```bash
uv run pytest           # 단위 테스트
uv run ruff check .     # 린트
uv run ruff format .    # 포맷
```

## 알려진 한계

- `librosa.beat.tempo`는 짧거나 비대칭 곡에서 오차가 큼 → `--bpm-hint` 권장
- 균일한 고에너지 곡(예: 본 프로젝트의 loopable 트랙)은 후반부가 7-8 측에 몰림 → `--band low` 변경 또는 `--max-sides` 축소로 변동성 회복
