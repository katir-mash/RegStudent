# RegStudent Mobile

Flutter 3.24.5 · Android · Python REST API · SQLite. Мобильді клиент №8 жобасының серверін қолданады. Қосымшада жеке студенттік деректер сақталмайды. Сессия жадта, жазбалар серверде сақталады.

## Іске қосу

1. Репозиторий түбінде Python виртуалды ортасын жасап, `python -m pip install -r requirements.txt` орындаңыз.
2. Әкімші құрыңыз: `python registry.py --add-user registrar --role admin`. 12–128 таңбалы пароль таңдаңыз. Оқырман қажет болса, `python registry.py --add-user observer --role reader` орындаңыз.
3. `python registry.py` арқылы серверді іске қосыңыз. Әдепкі порт 8080.
4. Android эмуляторын немесе USB debugging қосылған Android телефонын жалғап, бөлек терминалда `adb reverse tcp:8080 tcp:8080` орындаңыз. Сервер мен adb бір компьютерде іске қосылады.
5. Осы mobile каталогында `flutter pub get`, содан кейін `flutter run` орындаңыз. Дайын APK болса, оны `adb install -r app-debug.apk` арқылы орнатуға болады.
6. registrar логинін және 2-қадамда таңдаған парольді енгізіңіз. Деректерді тіркеу үшін әкімші құқығы қажет. Оқырман іздеп, сұрыптап, қарай алады.

## Тексеру

`flutter test` unit және widget тесттерін жүргізеді. Жаңа уақытша SQLite базасында mobile/tool/seed_ci.py сынақ аккаунттарын және бір студентті дайындайды. CI Android эмуляторында flutter drive арқылы нақты серверге кіріп, бес экранды, CRUD, сақталуды және қате жағдайларын тексереді. Қосылым үзілгенде жазу сәтті деп көрсетілмейді. Басқа серверге қосылу үшін `--dart-define=API_BASE=https://your-server.example` параметрін беріңіз.
