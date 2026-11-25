# Студенттерді тіркеу жүйесі · №8 зертханалық жұмыс

1-нұсқа. Жүйеге әкімші студентті тіркеп, деректерін өзгертіп, өшіре алады. Оқырман тізім мен жеке жазбаны қарай алады. Интерфейс қазақ тілінде. Сервер тек 127.0.0.1 мекенжайын тыңдайды.

## Орнату

Python 3.12 және Git қажет. ZIP архивін ашып, осы README орналасқан каталогта терминалды іске қосыңыз.

Windows PowerShell:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements.txt
.\.venv\Scripts\python registry.py --add-user registrar --role admin
.\.venv\Scripts\python registry.py
```

macOS немесе Linux:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python registry.py --add-user registrar --role admin
python registry.py
```

Алғашқы іске қосуда 12–128 таңбалы пароль енгізіңіз. Браузерде http://127.0.0.1:8080 ашып, registrar логинімен кіріңіз. Топ үлгісі — IT-3. Жаңа студентке ID өрісін бос қалдырыңыз. Өзгерту үшін кестедегі ID нөмірін көрсетіңіз. Оқырманды бөлек терминалдан `python registry.py --add-user observer --role reader` командасымен құруға болады. Сервер қайта іске қосылса, жүйеге қайта кіріңіз.

## Тексеру

Виртуалды ортаны іске қосыңыз (Windows-та `.\.venv\Scripts\python` арқылы python командасын ауыстыруға болады).

```bash
python -m pytest -v --junitxml=junit.xml
python -m bandit registry.py
python bench/run.py
```

Тесттер бөлек уақытша деректер қорын жасайды. Locust сынағына шамамен 9 минут қажет. bench/run.py 18738 портында бөлек серверді өзі іске қосады, 100 жасанды жазба жасайды және CSV файлдарын evidence/load каталогына жазады. Бұл скриптті қайта іске қосу бұрынғы жүктеме өлшемдерін жаңартады.

## GitHub Actions

.github/workflows/test.yml push, pull_request және қолмен іске қосу оқиғаларында pytest және Bandit құралдарын орындайды. Әр жүгірудің JUnit есебі test-results артефактіне салынады. Практикада аты 80 таңбалы студентке арналған тест шекаралық қатені көрсетеді. Бастапқы және түзетілген нұсқаларды бөлек тексеруге арналған Git тарихы ZIP ішіндегі registry-history.bundle файлында берілген.

## Құрамы

| Файл | Мақсаты |
|---|---|
| registry.py | REST API, SQLite схемасы, рөлдер, енгізуді тексеру |
| index.html | Жүйеге кіру, студенттер тізімі, тіркеу және өзгерту формасы |
| tests/ | HTTP, деректер қоры, шекаралық мәндер және қауіпсіздік сценарийлері |
| bench/ | Locust пайдаланушы сценарийі және төрт жүктеме профилін орындау |
| evidence/ | Жергілікті сынақ нәтижелері, CSV, журналдар және JUnit |


## №9–11 · RegStudent Mobile

[Flutter қолданбасы және іске қосу нұсқаулығы](mobile/README.md) · [Бес экранның Figma макеті](design/RegStudent.fig) · [Офлайн интерактивті прототип](design/Prototype.html)

Android клиенті осы Flask API мен SQLite базасын пайдаланады. `RegStudent Android` workflow APK құрастырады, unit және widget тесттерін орындайды және Android эмуляторын нақты сервермен тексереді. Жүктеп алынған `Prototype.html` браузерде тікелей ашылады.
