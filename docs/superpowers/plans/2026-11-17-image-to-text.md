# image-to-text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Скилл, который читает текст с изображений и PDF через Tesseract 5, отдаёт JSON+Markdown с bbox и confidence и никогда не подставляет слова молча.

**Architecture:** Пакет `image_to_text` из пяти модулей (preprocess → ocr → layout → correct → report) плюс CLI `scripts/see.py`. Каждый модуль — чистая функция или маленький класс с явным контрактом, поэтому тестируется без Tesseract, кроме одного интеграционного теста на реальном файле.

**Tech Stack:** Python 3.15, stdlib `unittest` (pytest не установлен), Pillow, numpy, RapidFuzz, CLI `tesseract 5.5.4`, `pdftoppm`, `magick`.

**Spec:** `docs/superpowers/specs/2026-11-17-image-to-text-design.md`

## Global Constraints

- Скилл живёт в `~/.config/opencode/skills/image-to-text/`, это отдельный git-репозиторий (`git init` в Task 1).
- Зависимости только: Pillow, numpy, RapidFuzz. Никаких `pip install` в задачах.
- Тесты запускаются `python3 -m unittest discover -s tests -v` из корня скилла.
- Языки OCR по умолчанию `rus+eng`; `langs` — строка в формате Tesseract.
- Константы (значения менять только вместе с тестами): `SCALE_SMALL_MIN_DIM = 1200`, `SCALE_SMALL = 2.0`, `SCALE_LARGE = 1.5`, `MAX_DIM = 6000`, `PDF_MAX_PAGES = 5`, `PSM_CANDIDATES = (3, 6, 11)`, `LOWCONF_RATIO = 0.25`, `SUGGEST_MIN_SCORE = 85`, `SUGGEST_MAX_DIST = 2`, `READABLE_MEAN_CONF = 60`, `READABLE_MIN_WORDS = 3`.
- Словари: `/usr/share/hunspell/ru_RU.dic`, `/usr/share/hunspell/en_US.dic`.
- Никакой автозамены: `suggest` только предлагает.
- Сообщения об ошибках — на русском, код возврата CLI: 0 успех, 2 ошибка входа.

## Review Focus

- **Прозрачный PNG** (иконка с альфа-каналом): альфа композитится на белый, а не на чёрный — иначе полярность определяется неверно. Тест в Task 2.
- **Изображение без текста** (фото, градиент): `readable: false`, пустые блоки, без выдуманных слов. Тест в Task 7.
- **Очень большое изображение** (4000×3000): масштаб ограничен `MAX_DIM`, время работы остаётся секундами, без MemoryError. Тест в Task 2.
- **Многостраничный PDF**: берутся первые 5 страниц, в `meta.pages` — реальное число страниц. Тест в Task 2.
- **Битый или неподдерживаемый файл**: одно понятное сообщение, код возврата 2, без трейсбека. Тест в Task 7.

---

### Task 1: Каркас скилла и препроцессинг

**Files:**
- Create: `~/.config/opencode/skills/image-to-text/image_to_text/__init__.py`
- Create: `~/.config/opencode/skills/image-to-text/image_to_text/preprocess.py`
- Create: `~/.config/opencode/skills/image-to-text/tests/__init__.py`
- Create: `~/.config/opencode/skills/image-to-text/tests/test_preprocess.py`
- Create: `~/.config/opencode/skills/image-to-text/.gitignore`

**Interfaces:**
- Produces: `detect_polarity(img: Image.Image, border: int = 8) -> str` → `"light"` | `"dark"`; `estimate_scale(width: int, height: int) -> float`; `stretch_contrast(img: Image.Image, low_pct: float = 2.0, high_pct: float = 98.0) -> Image.Image`; `prepare(img: Image.Image, scale: float) -> Image.Image`.

- [ ] **Step 1: Инициализировать репозиторий скилла**

```bash
mkdir -p ~/.config/opencode/skills/image-to-text/{image_to_text,tests,scripts}
cd ~/.config/opencode/skills/image-to-text && git init -q
printf '__pycache__/\n*.pyc\n' > .gitignore
```

- [ ] **Step 2: Написать падающий тест**

`tests/test_preprocess.py`:

```python
import unittest
from PIL import Image
from image_to_text.preprocess import detect_polarity, estimate_scale, stretch_contrast

def solid(color, size=(100, 40)):
    return Image.new("RGB", size, color)

class TestPreprocess(unittest.TestCase):
    def test_light_background(self):
        img = solid("white"); img.paste("black", (40, 15, 60, 25))
        self.assertEqual(detect_polarity(img), "light")

    def test_dark_background(self):
        img = solid("black"); img.paste("white", (40, 15, 60, 25))
        self.assertEqual(detect_polarity(img), "dark")

    def test_scale_small_image(self):
        self.assertEqual(estimate_scale(782, 460), 2.0)

    def test_scale_large_image(self):
        self.assertEqual(estimate_scale(2400, 1400), 1.5)

    def test_contrast_stretch_bounds(self):
        arr = np.tile(np.linspace(40, 200, 20, dtype=np.uint8), (20, 1))
        out = stretch_contrast(Image.fromarray(arr))
        self.assertEqual(out.mode, "L")
        self.assertEqual(out.getextrema(), (0, 255))

    def test_contrast_stretch_uniform_unchanged(self):
        out = stretch_contrast(Image.new("L", (10, 10), 100))
        self.assertEqual(out.getextrema(), (100, 100))

    def test_scale_capped_by_max_dim(self):
        self.assertEqual(estimate_scale(6000, 4000), 1.0)
```

- [ ] **Step 3: Убедиться, что тест падает**

Run: `cd ~/.config/opencode/skills/image-to-text && python3 -m unittest tests.test_preprocess -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'image_to_text'` (или `detect_polarity`).

- [ ] **Step 4: Реализовать `preprocess.py`**

Полярность: средняя яркость рамки шириной `border`; `< 128` → `"dark"`. Масштаб: если `min(w,h) < SCALE_SMALL_MIN_DIM` → 2.0, иначе 1.5; затем ограничить так, чтобы `max(w,h) * scale <= MAX_DIM` (иначе 1.0). `stretch_contrast`: numpy-перцентили 2 и 98, линейное растяжение в 0–255; при `p_high == p_low` (равномерное изображение) вернуть изображение без изменений — никакой синтетики. `prepare`: `convert("L")` → resize `LANCZOS` → `stretch_contrast`.

- [ ] **Step 5: Прогнать тесты**

Run: `python3 -m unittest tests.test_preprocess -v`
Expected: PASS, 6 тестов.

- [ ] **Step 6: Коммит**

```bash
git add .gitignore image_to_text tests && git commit -m "feat: package skeleton and preprocessing"
```

---

### Task 2: Загрузка изображений (PNG/JPEG/WebP/PDF/SVG)

**Files:**
- Modify: `image_to_text/preprocess.py`
- Create: `tests/test_load.py`

**Interfaces:**
- Produces: `load_images(path: str, max_pages: int = 5) -> tuple[list[Image.Image], dict]`, где второй элемент — `{"format": str, "pages": int, "size": [w, h]}`; исключение `InputError(Exception)` с русским текстом.
- Consumes: `MAX_DIM`, `PDF_MAX_PAGES` из Task 1.

- [ ] **Step 1: Написать падающий тест**

`tests/test_load.py`:

```python
import os, tempfile, unittest
from PIL import Image
from image_to_text.preprocess import InputError, load_images

class TestLoad(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def save(self, name, img, **kw):
        p = os.path.join(self.dir, name); img.save(p, **kw); return p

    def test_png_alpha_composited_on_white(self):
        img = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
        pages, meta = load_images(self.save("a.png", img))
        self.assertEqual(len(pages), 1)
        self.assertEqual(meta["format"], "png")
        self.assertEqual(pages[0].convert("L").getpixel((5, 5)), 255)

    def test_missing_file_raises_input_error(self):
        with self.assertRaises(InputError):
            load_images(os.path.join(self.dir, "nope.png"))

    def test_unsupported_format_raises(self):
        p = os.path.join(self.dir, "a.txt")
        open(p, "w").write("hello")
        with self.assertRaises(InputError):
            load_images(p)

    def test_huge_image_is_loaded(self):
        p = self.save("big.png", Image.new("RGB", (4000, 3000), "white"))
        pages, meta = load_images(p)
        self.assertEqual(meta["size"], [4000, 3000])
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_load -v`
Expected: FAIL — `ImportError: cannot import name 'InputError'`.

- [ ] **Step 3: Реализовать `load_images`**

Pillow открывает png/jpeg/jpg/webp/bmp/tiff; RGBA/LA/P → `alpha_composite` на белый. PDF → `pdftoppm -r 200 -png -f 1 -l max_pages` во временный каталог, страницы сортируются по имени, `meta["pages"]` — число отрисованных страниц. SVG → `magick input -background white -flatten out.png`. Всё остальное и отсутствующие файлы → `InputError("Не удалось прочитать файл …: <причина>")`. Размер в meta — исходный, до масштабирования.

- [ ] **Step 4: Прогнать тесты**

Run: `python3 -m unittest tests.test_load -v`
Expected: PASS, 4 теста.

- [ ] **Step 5: Коммит**

```bash
git add -A && git commit -m "feat: image loading with alpha, pdf and svg support"
```

---

### Task 3: OCR через TSV и выбор PSM

**Files:**
- Create: `image_to_text/ocr.py`
- Create: `tests/test_ocr.py`

**Interfaces:**
- Produces: `Word` (dataclass: `block, par, line, left, top, width, height, conf: float, text: str`); `parse_tsv(tsv: str) -> list[Word]`; `score(words: list[Word]) -> float`; `lowconf_ratio(words: list[Word], min_conf: int = 70) -> float`; `run_tesseract(img: Image.Image, langs: str, psm: int) -> str`; `recognize(img: Image.Image, langs: str, psm: str = "auto", min_conf: int = 70) -> OcrResult` (`OcrResult` = dataclass `psm: int, words: list[Word], mean_conf: float`).

- [ ] **Step 1: Написать падающий тест**

`tests/test_ocr.py` — фикстура TSV как строка (шапка + 4 строки слов) и подмена раннера:

```python
TSV = """level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
5\t1\t1\t1\t1\t1\t10\t10\t40\t12\t90.0\tСлои
5\t1\t1\t1\t1\t2\t60\t10\t60\t12\t80.0\tДизайн
5\t1\t1\t2\t1\t1\t10\t40\t30\t12\t40.0\tФрейм
5\t1\t1\t2\t1\t2\t50\t40\t50\t12\t30.0\tИнспект"""

class TestOcr(unittest.TestCase):
    def test_parse_tsv_words(self):
        words = parse_tsv(TSV)
        self.assertEqual(len(words), 4)
        self.assertEqual(words[0].text, "Слои")
        self.assertAlmostEqual(words[2].conf, 40.0)

    def test_score_empty_is_zero(self):
        self.assertEqual(score([]), 0.0)

    def test_score_formula(self):
        words = [Word(1,1,1,0,0,1,1,85.0,"a"), Word(1,1,1,0,0,1,1,85.0,"b")]
        self.assertAlmostEqual(score(words), 85.0 * math.log(3), places=2)

    def test_lowconf_ratio(self):
        self.assertAlmostEqual(lowconf_ratio(parse_tsv(TSV)), 0.5)

    def test_auto_picks_better_psm(self):
        calls = []
        def fake(img, langs, psm):
            calls.append(psm)
            return TSV if psm == 6 else "level\n5\t1\t1\t1\t1\t1\t0\t0\t1\t1\t10.0\tx"
        with mock.patch("image_to_text.ocr.run_tesseract", fake):
            res = recognize(Image.new("L", (10, 10)), "rus+eng", "auto")
        self.assertEqual(res.psm, 6)
        self.assertEqual(calls, [3, 6])
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_ocr -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'image_to_text.ocr'`.

- [ ] **Step 3: Реализовать `ocr.py`**

`run_tesseract`: сохранить PNG во временный файл, `subprocess.run(["tesseract", path, "stdout", "-l", langs, "--psm", str(psm), "tsv"], capture_output=True, text=True)`, при `returncode != 0` — `RuntimeError` с stderr. `parse_tsv`: строки с `level == "5"` и непустым `text.strip()`. `score = mean_conf * log(1 + n)`, при `n == 0` → 0.0. `recognize`: прогон `psm=3`; если `score < 8 * log(2)` или `lowconf_ratio > LOWCONF_RATIO` — прогнать 6 и 11, вернуть результат с максимальным `score`. `mean_conf` — среднее по словам (0.0 при пустом списке).

- [ ] **Step 4: Прогнать тесты**

Run: `python3 -m unittest tests.test_ocr -v`
Expected: PASS, 5 тестов.

- [ ] **Step 5: Коммит**

```bash
git add -A && git commit -m "feat: tesseract tsv parsing and psm auto-selection"
```

---

### Task 4: Сборка блоков и структура

**Files:**
- Create: `image_to_text/layout.py`
- Create: `tests/test_layout.py`

**Interfaces:**
- Produces: `Line` (`bbox: tuple[int,int,int,int]`, `text: str`, `words: list[Word]`, `kind: str`); `Block` (`bbox`, `kind`, `conf: float`, `lines: list[Line]`); `build_blocks(words: list[Word]) -> list[Block]`; `classify_line(words: list[Word], line_h: float, median_h: float) -> str` → `"heading" | "list" | "code" | "paragraph"`.
- Consumes: `Word` из Task 3.

- [ ] **Step 1: Написать падающий тест**

```python
class TestLayout(unittest.TestCase):
    def test_two_lines_one_block(self):
        ws = [W(1,1,1,10,10,40,12,90,"Слои"), W(1,1,1,60,10,60,12,90,"Дизайн"),
              W(1,1,2,10,40,40,12,90,"Строка")]
        blocks = build_blocks(ws)
        self.assertEqual(len(blocks), 1)
        self.assertEqual(len(blocks[0].lines), 2)
        self.assertEqual(blocks[0].lines[0].text, "Слои Дизайн")

    def test_heading_by_height(self):
        self.assertEqual(classify_line([W(...)], 24.0, 16.0), "heading")

    def test_list_by_bullet(self):
        self.assertEqual(classify_line([W(...text="• пункт")], 16.0, 16.0), "list")

    def test_code_by_monospace(self):
        self.assertEqual(classify_line([W(...text="see.py")], 16.0, 16.0), "code")
```

(`W(...)` — сокращение конструктора `Word` с нужными полями; в реальном тесте поля заполняются явно.)

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_layout -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'image_to_text.layout'`.

- [ ] **Step 3: Реализовать `layout.py`**

Группировка по `(block, par, line)` с сохранением порядка появления; текст строки — слова через пробел; bbox — объединение. `kind` блока — `kind` первой строки. `classify_line`: высота строки `> 1.25 * median_h` → `heading`; текст начинается с `•`, `-`, `*`, `·` или с `^\d+[.)]\s` → `list`; моноширинность: `stdev(ширины слова / длина слова) / среднее < 0.15` при слове длиной ≥ 4 → `code`; иначе `paragraph`.

- [ ] **Step 4: Прогнать тесты**

Run: `python3 -m unittest tests.test_layout -v`
Expected: PASS, 4 теста.

- [ ] **Step 5: Коммит**

```bash
git add -A && git commit -m "feat: block assembly and structure heuristics"
```

---

### Task 5: Словарь и подсказки

**Files:**
- Create: `image_to_text/correct.py`
- Create: `tests/test_correct.py`

**Interfaces:**
- Produces: `load_lexicon(paths: list[str] | None = None) -> set[str]` (по умолчанию оба словаря hunspell, слова в нижнем регистре); `suggestions(word: str, lexicon: set[str], min_score: int = 85, max_dist: int = 2) -> list[str]` (не более 3, по убыванию score); `is_known(word: str, lexicon: set[str]) -> bool` (без учёта регистра, пунктуация по краям срезается).

- [ ] **Step 1: Написать падающий тест**

```python
class TestCorrect(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lex = {"слои", "дизайн", "фрейм", "страницы"}

    def test_known_word(self):
        self.assertTrue(is_known("Слои,", self.lex))

    def test_typo_gets_candidate(self):
        self.assertIn("страницы", suggestions("стпаницы", self.lex))

    def test_nonsense_gets_nothing(self):
        self.assertEqual(suggestions("ъъъъъ", self.lex), [])

    def test_max_three_candidates(self):
        self.assertLessEqual(len(suggestions("страниц", self.lex)), 3)
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_correct -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'image_to_text.correct'`.

- [ ] **Step 3: Реализовать `correct.py`**

`load_lexicon`: читать `.dic`, пропускать первую строку (число слов) и строки с `/` (флаги hunspell) — брать часть до `/`; при отсутствии файла — молча пропустить. `suggestions`: `rapidfuzz.process.extract(word.lower(), lexicon, scorer=fuzz.ratio, limit=20)`, фильтр `score >= min_score` и `levenshtein <= max_dist`, вернуть до 3.

- [ ] **Step 4: Прогнать тесты**

Run: `python3 -m unittest tests.test_correct -v`
Expected: PASS, 4 теста.

- [ ] **Step 5: Коммит**

```bash
git add -A && git commit -m "feat: hunspell lexicon and fuzzy suggestions"
```

---

### Task 6: Отчёт JSON и Markdown

**Files:**
- Create: `image_to_text/report.py`
- Create: `tests/test_report.py`

**Interfaces:**
- Produces: `build_report(pages: list[BlockGroup], meta: dict, min_conf: int = 70) -> dict`; `to_markdown(report: dict) -> str`. Ключи отчёта: `readable: bool`, `meta`, `blocks`, `uncertain: list[{text, conf, bbox, suggest}]`, `markdown: str`.
- Consumes: `Block` из Task 4, `suggestions` из Task 5.

- [ ] **Step 1: Написать падающий тест**

```python
class TestReport(unittest.TestCase):
    def test_not_readable_on_empty(self):
        rep = build_report([], {"size": [10, 10]})
        self.assertFalse(rep["readable"])
        self.assertEqual(rep["blocks"], [])

    def test_uncertain_collected_with_suggestions(self):
        rep = build_report([blocks_with_low_conf()], {"size": [10, 10]})
        self.assertEqual(len(rep["uncertain"]), 1)
        self.assertIn("suggest", rep["uncertain"][0])

    def test_markdown_marks_uncertain(self):
        md = to_markdown(build_report([blocks_with_low_conf()], {"size": [10, 10]}))
        self.assertIn("неуверенно", md)
        self.assertIn("?", md)

    def test_json_is_serialisable(self):
        json.dumps(build_report([blocks_with_low_conf()], {"size": [10, 10]}))
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_report -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'image_to_text.report'`.

- [ ] **Step 3: Реализовать `report.py`**

`readable = mean_conf >= READABLE_MEAN_CONF and total_words >= READABLE_MIN_WORDS`. `uncertain` — слова с `conf < min_conf`, каждое с `suggest` (для известных слов — пустой список). `to_markdown`: блоки по порядку, заголовки через `##`, код в ``` ``` ```, списки как есть; в конце раздел `## Неуверенно` со строкой на слово: `- «текст» (conf 41) → кандидаты: …`. Если слова нет в словаре и кандидатов нет — `(нет кандидатов)`.

- [ ] **Step 4: Прогнать тесты**

Run: `python3 -m unittest tests.test_report -v`
Expected: PASS, 4 теста.

- [ ] **Step 5: Коммит**

```bash
git add -A && git commit -m "feat: json and markdown report"
```

---

### Task 7: CLI `see.py`

**Files:**
- Create: `scripts/see.py`
- Create: `tests/test_cli.py`

**Interfaces:**
- Produces: `main(argv: list[str] | None = None) -> int`; флаги `--json`, `--md`, `--langs` (по умолчанию `rus+eng`), `--psm` (`auto|3|6|11`), `--scale` (`auto|1..4`), `--crop x,y,w,h`, `--min-conf` (70), `--no-suggest`.
- Consumes: всё предыдущее.

- [ ] **Step 1: Написать падающий тест**

```python
class TestCli(unittest.TestCase):
    def test_blank_image_not_readable(self):
        p = save_blank_png()
        rc = main([p, "--json"])
        self.assertEqual(rc, 0)

    def test_missing_file_exit_2(self):
        self.assertEqual(main(["/nonexistent/x.png"]), 2)

    def test_pdf_page_limit_message(self):
        # PDF с 7 страницами: в meta.pages == 5
        ...
```

Плюс интеграционный тест на реальном скриншоте: запустить `main([shot, "--json"])`, распарсить stdout, проверить `readable is True` и что в тексте есть `Слои` (файл `tests/fixtures/screenshot.png`, копия `eMake-and-Draw/docs/screenshot.png`).

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_cli -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'scripts.see'` (или отсутствует `main`).

- [ ] **Step 3: Реализовать `scripts/see.py`**

Добавить `sys.path.insert(0, str(Path(__file__).resolve().parent.parent))`, разобрать аргументы, `load_images` → `prepare` (масштаб из `--scale` или `estimate_scale`) → `recognize` → `build_blocks` → `build_report` → печать Markdown (по умолчанию) или JSON (`--json`). `InputError` → `print(f"Ошибка: {e}", file=sys.stderr)`, return 2. `--crop` применяется к исходному изображению до масштабирования. Время работы и выбранный psm — только в `meta`, не в stdout Markdown.

- [ ] **Step 4: Прогнать тесты**

Run: `python3 -m unittest discover -s tests -v`
Expected: PASS, все тесты (включая интеграционный, ~2–5 с).

- [ ] **Step 5: Ручная проверка**

```bash
python3 scripts/see.py "/home/ruzik-admin/Документы/Проект по умолчанию/eMake-and-Draw/docs/screenshot.png" --md
```

Ожидаемо: читаемый текст интерфейса (Страницы, Слои, Прямоугольник, Дизайн…), в конце — раздел «Неуверенно», если есть слабые слова.

- [ ] **Step 6: Коммит**

```bash
git add -A && git commit -m "feat: see.py cli"
```

---

### Task 8: SKILL.md, тестовый набор и бенчмарк

**Files:**
- Create: `SKILL.md`
- Create: `scripts/bench.py`
- Create: `tests/fixtures/*` и `tests/expected/*.txt`
- Create: `tests/test_bench.py`

**Interfaces:**
- Produces: `bench.run(pairs: list[tuple[str, str]]) -> list[dict]` (`name, cer, wer, words`), CLI `python3 scripts/bench.py [--baseline PATH]`.

- [ ] **Step 1: Написать падающий тест**

```python
class TestBench(unittest.TestCase):
    def test_cer_identical_is_zero(self):
        self.assertEqual(cer("привет мир", "привет мир"), 0.0)

    def test_cer_one_substitution(self):
        self.assertAlmostEqual(cer("привет мир", "привет мор"), 1 / 10)

    def test_wer_counts_word_errors(self):
        self.assertAlmostEqual(wer("a b c", "a x c"), 1 / 3)
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 -m unittest tests.test_bench -v`
Expected: FAIL — `ModuleNotFoundError`.

- [ ] **Step 3: Реализовать `bench.py` и собрать `tests/`**

CER/WER через `rapidfuzz.distance.Levenshtein`. Набор: `screenshot.png` (eMake-and-Draw), `icon256.png` (`rust-calendar/assets/icon-256.png`), тёмный скриншот чата, белый лист с мелким текстом (сгенерировать Pillow, шрифт DejaVu). Эталоны — `tests/expected/<name>.txt`, набраны вручную по факту чтения. `--baseline` принимает путь к распакованному старому скрипту и печатает его WER рядом.

- [ ] **Step 4: Прогнать тесты и бенчмарк**

Run: `python3 -m unittest discover -s tests -v && python3 scripts/bench.py`
Expected: PASS; таблица с WER по каждому файлу, суммарный WER < 8 % на скриншотах.

- [ ] **Step 5: Написать `SKILL.md`**

Frontmatter: `name: image-to-text`, `description: "Use when you need to read text from an image or PDF — screenshots, UI, documents, diagrams with labels — especially when exact words matter…"` (только триггеры, без пересказа процесса, по требованиям к скиллам).

Тело: когда применять / когда нет (фото, сцены, рукописное — прямо сказать, что скилл читает только текст); обязательный запуск `scripts/see.py`; запрет писать собственное распознавание глифов; правила отчёта (дословно из JSON, правки по контексту с пометкой, `uncertain` не додумывать); эскалация при плохом результате (×2/×3, `--crop`, `--tile`); формат ответа с `clear/likely/uncertain`.

- [ ] **Step 6: Коммит**

```bash
git add -A && git commit -m "feat: skill docs, fixtures and wer benchmark"
```

---

## Self-review

- Покрытие спеки: конвейер (Tasks 1–3), структура (Task 4), `suggest` без автозамены (Task 5), отчёт (Task 6), CLI-контракт (Task 7), SKILL.md и проверка WER (Task 8). Не покрыто сознательно: `--tile` — упомянут в SKILL.md как эскалация, реализация в v1 отсутствует; если понадобится, это отдельная задача.
- Типы согласованы: `Word` → `Line/Block` → `report` используют одинаковые имена полей (`bbox`, `conf`, `text`, `words`).
- Review Focus: прозрачность и размер — Task 2; пустое изображение и битый файл — Task 7; PDF — Task 2 и Task 7.
