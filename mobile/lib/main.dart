import 'package:flutter/material.dart';
import 'registry.dart';

const ink = Color(0xff172d31);
const teal = Color(0xff086762);
const paper = Color(0xfff3f6f2);
const apiOrigin =
    String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8080');
void main() => runApp(RegistryApp(api: RegistryApi(Uri.parse(apiOrigin))));

class RegistryApp extends StatelessWidget {
  final RegistryApi api;
  const RegistryApp({super.key, required this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'RegStudent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: teal, primary: teal),
          scaffoldBackgroundColor: paper,
          appBarTheme: const AppBarTheme(
              backgroundColor: paper,
              foregroundColor: ink,
              surfaceTintColor: Colors.transparent),
          inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder())),
      home: Login(api: api));
}

Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(text,
        style: const TextStyle(
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w700,
            color: ink)));
Widget field(String key, String label, TextEditingController controller,
        {bool obscure = false,
        String? Function(String)? check,
        TextInputType? type}) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
            key: ValueKey(key),
            controller: controller,
            obscureText: obscure,
            autocorrect: !obscure,
            enableSuggestions: !obscure,
            keyboardType: type,
            validator: (v) => check?.call(v ?? ''),
            decoration: InputDecoration(labelText: label)));

class Login extends StatefulWidget {
  final RegistryApi api;
  const Login({super.key, required this.api});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final login = TextEditingController(), pass = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String error = '';
  @override
  void dispose() {
    login.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.api.signIn(login.text.trim(), pass.text);
      if (!mounted) return;
      pass.clear();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => Desk(api: widget.api)));
    } on RegistryError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('RegStudent')),
      body: SafeArea(
          child: Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                const SizedBox(height: 36),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                        radius: 29,
                        backgroundColor: teal,
                        child: Icon(Icons.school_outlined,
                            color: Colors.white, size: 32))),
                const SizedBox(height: 22),
                heading('Жүйеге кіру'),
                field('login', 'Логин', login,
                    check: (v) =>
                        v.trim().isEmpty ? 'Логинді енгізіңіз' : null),
                field('password', 'Пароль', pass,
                    obscure: true,
                    check: (v) => v.isEmpty ? 'Парольді енгізіңіз' : null),
                if (error.isNotEmpty)
                  Text(error,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                FilledButton(
                    key: const Key('enter'),
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'Күтіңіз…' : 'Кіру')),
              ]))));
}

class Desk extends StatefulWidget {
  final RegistryApi api;
  const Desk({super.key, required this.api});
  @override
  State<Desk> createState() => _DeskState();
}

class _DeskState extends State<Desk> {
  int tab = 0, requestNo = 0;
  List<Student> rows = [];
  bool loading = true, ascending = true;
  String query = '', error = '';
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final seq = ++requestNo;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final list = await widget.api.list();
      if (mounted && seq == requestNo) setState(() => rows = list);
    } on RegistryError catch (e) {
      if (mounted && seq == requestNo) setState(() => error = e.message);
    } finally {
      if (mounted && seq == requestNo) setState(() => loading = false);
    }
  }

  void signOut() {
    widget.api.signOut();
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => Login(api: widget.api)),
        (_) => false);
  }

  Future<void> edit([Student? s]) async {
    if (!widget.api.admin) return;
    final result = await Navigator.push<String>(context,
        MaterialPageRoute(builder: (_) => Editor(api: widget.api, student: s)));
    if (!mounted || result == null) return;
    setState(() {
      tab = 1;
      query = '';
    });
    await reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  Widget home() => ListView(padding: const EdgeInsets.all(20), children: [
        heading('Студенттер тізілімі'),
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: teal, borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Тіркелген студенттер',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              Text(loading || error.isNotEmpty ? '—' : '${rows.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold))
            ])),
        const SizedBox(height: 24),
        FilledButton.icon(
            key: const Key('browse'),
            onPressed: () => setState(() => tab = 1),
            icon: const Icon(Icons.list_alt),
            label: const Text('Тізімді ашу')),
        if (widget.api.admin)
          OutlinedButton.icon(
              key: const Key('newHome'),
              onPressed: () => edit(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Студент қосу'))
      ]);
  Widget directory() {
    final data = filtered(rows, query, ascending);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: heading('Студенттер')),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
                child: TextFormField(
                    key: ValueKey('search'),
                    initialValue: query,
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                        labelText: 'Аты немесе тобы',
                        prefixIcon: Icon(Icons.search)))),
            IconButton(
                key: const Key('sort'),
                tooltip: ascending ? 'Кему реті' : 'Өсу реті',
                onPressed: () => setState(() => ascending = !ascending),
                icon:
                    Icon(ascending ? Icons.arrow_downward : Icons.arrow_upward))
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child:
              Text('${data.length} жазба · ${ascending ? "А → Я" : "Я → А"}')),
      Expanded(
          child: data.isEmpty
              ? Center(
                  child: Text(loading
                      ? 'Жүктелуде…'
                      : query.isEmpty
                          ? 'Тізім бос'
                          : 'Сәйкес жазба жоқ'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 82),
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final s = data[i];
                    return Card(
                        color: Colors.white,
                        child: ListTile(
                            key: ValueKey('student-${s.id}'),
                            leading: const CircleAvatar(
                                child: Icon(Icons.person_outline)),
                            title: Text(s.name),
                            subtitle: Text('${s.cohort}\n${s.email}'),
                            isThreeLine: true,
                            trailing: widget.api.admin
                                ? const Icon(Icons.edit_outlined)
                                : null,
                            onTap: widget.api.admin ? () => edit(s) : null));
                  }))
    ]);
  }

  Widget profile() => ListView(padding: const EdgeInsets.all(20), children: [
        heading('Профиль'),
        Card(
            child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(widget.api.loginName),
                subtitle: Text(widget.api.admin ? 'Әкімші' : 'Оқырман'))),
        const SizedBox(height: 20),
        OutlinedButton(
            key: const Key('logout'),
            onPressed: signOut,
            child: const Text('Жүйеден шығу'))
      ]);
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && tab != 0) setState(() => tab = 0);
      },
      child: Scaffold(
          appBar: AppBar(title: const Text('RegStudent'), actions: [
            IconButton(
                key: const Key('refresh'),
                tooltip: 'Жаңарту',
                onPressed: loading ? null : reload,
                icon: const Icon(Icons.refresh))
          ]),
          body: SafeArea(
              child: Column(children: [
            if (error.isNotEmpty)
              Material(
                  color: const Color(0xffffe8dc),
                  child: ListTile(
                      title: Text(error),
                      trailing: IconButton(
                          onPressed: reload,
                          tooltip: 'Қайталау',
                          icon: const Icon(Icons.replay)))),
            Expanded(child: [home, directory, profile][tab]())
          ])),
          floatingActionButton: tab == 1 && widget.api.admin
              ? FloatingActionButton(
                  key: const Key('new'),
                  tooltip: 'Студент қосу',
                  onPressed: () => edit(),
                  child: const Icon(Icons.add))
              : null,
          bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(
                    key: Key('homeTab'),
                    icon: Icon(Icons.home_outlined),
                    label: 'Басты'),
                NavigationDestination(
                    key: Key('dataTab'),
                    icon: Icon(Icons.people_outline),
                    label: 'Тізім'),
                NavigationDestination(
                    key: Key('profileTab'),
                    icon: Icon(Icons.person_outline),
                    label: 'Профиль')
              ])));
}

class Editor extends StatefulWidget {
  final RegistryApi api;
  final Student? student;
  const Editor({super.key, required this.api, this.student});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, email, group;
  bool busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    final s = widget.student;
    name = TextEditingController(text: s?.name);
    email = TextEditingController(text: s?.email);
    group = TextEditingController(text: s?.cohort);
  }

  @override
  void dispose() {
    for (final c in [name, email, group]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> commit({bool remove = false}) async {
    if (busy || (!remove && !form.currentState!.validate())) return;
    if (remove) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Студентті жою керек пе?'),
                  content: Text(widget.student!.name),
                  actions: [
                    TextButton(
                        key: const Key('cancelDelete'),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Бас тарту')),
                    FilledButton(
                        key: const Key('confirmDelete'),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Жою'))
                  ]));
      if (ok != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (remove) {
        await widget.api.remove(widget.student!.id);
      } else {
        await widget.api
            .save(widget.student?.id, name.text, email.text, group.text);
      }
      if (mounted)
        Navigator.pop(context, remove ? 'Жазба жойылды' : 'Жазба сақталды');
    } on RegistryError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              widget.student == null ? 'Жаңа студент' : 'Студентті өңдеу')),
      body: SafeArea(
          child: Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                heading('Студент деректері'),
                field('name', 'Аты-жөні', name, check: validateName),
                field('email', 'Email', email,
                    check: validateEmail, type: TextInputType.emailAddress),
                field('cohort', 'Топ', group, check: validateGroup),
                if (error.isNotEmpty)
                  Text(error,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                FilledButton(
                    key: const Key('save'),
                    onPressed: busy ? null : () => commit(),
                    child: const Text('Сақтау')),
                if (widget.student != null)
                  TextButton(
                      key: const Key('delete'),
                      onPressed: busy ? null : () => commit(remove: true),
                      child: const Text('Жазбаны жою'))
              ]))));
}
