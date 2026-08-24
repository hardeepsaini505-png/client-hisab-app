
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HisabApp());
}

class HisabApp extends StatelessWidget {
  const HisabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Client Hisab',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const LockScreen(),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final controller = TextEditingController();
  String error = '';

  void login() {
    if (controller.text == '7391') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => error = 'Wrong password');
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.lock, size: 70),
                    const SizedBox(height: 15),
                    const Text('App Locked',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => login(),
                    ),
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: login,
                        icon: const Icon(Icons.login),
                        label: const Text('Unlock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Firm {
  String id;
  String name;
  Firm({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Firm.fromJson(Map<String, dynamic> j) =>
      Firm(id: j['id'], name: j['name']);
}

class Client {
  String id;
  String firmId;
  String name;
  String phone;
  String remark;

  Client({
    required this.id,
    required this.firmId,
    required this.name,
    this.phone = '',
    this.remark = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'firmId': firmId,
        'name': name,
        'phone': phone,
        'remark': remark,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'],
        firmId: j['firmId'],
        name: j['name'],
        phone: j['phone'] ?? '',
        remark: j['remark'] ?? '',
      );
}

class Entry {
  String id;
  String clientId;
  String date;
  String work;
  double amount;
  double payment;
  String remark;

  Entry({
    required this.id,
    required this.clientId,
    required this.date,
    required this.work,
    this.amount = 0,
    this.payment = 0,
    this.remark = '',
  });

  double get pending => amount - payment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'date': date,
        'work': work,
        'amount': amount,
        'payment': payment,
        'remark': remark,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'],
        clientId: j['clientId'],
        date: j['date'],
        work: j['work'],
        amount: (j['amount'] as num).toDouble(),
        payment: (j['payment'] as num).toDouble(),
        remark: j['remark'] ?? '',
      );
}

class AppData {
  List<Firm> firms = [];
  List<Client> clients = [];
  List<Entry> entries = [];

  Map<String, dynamic> toJson() => {
        'firms': firms.map((e) => e.toJson()).toList(),
        'clients': clients.map((e) => e.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final d = AppData();
    d.firms = (j['firms'] as List? ?? [])
        .map((e) => Firm.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    d.clients = (j['clients'] as List? ?? [])
        .map((e) => Client.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    d.entries = (j['entries'] as List? ?? [])
        .map((e) => Entry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return d;
  }
}

class Store {
  static const key = 'client_hisab_data';

  static Future<AppData> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) return AppData();
    try {
      return AppData.fromJson(jsonDecode(raw));
    } catch (_) {
      return AppData();
    }
  }

  static Future<void> save(AppData data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(data.toJson()));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppData data = AppData();
  bool loading = true;
  int tab = 0;
  String search = '';

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    data = await Store.load();
    setState(() => loading = false);
  }

  Future<void> save() async {
    await Store.save(data);
    if (mounted) setState(() {});
  }

  double clientBalance(String id) {
    return data.entries
        .where((e) => e.clientId == id)
        .fold(0.0, (s, e) => s + e.pending);
  }

  double totalPending() =>
      data.clients.fold(0.0, (s, c) => s + clientBalance(c.id));

  List<Client> get filteredClients {
    final q = search.toLowerCase().trim();
    return data.clients.where((c) {
      return q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();
  }

  Future<void> addFirm() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Firm'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
              labelText: 'Firm name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      data.firms.add(Firm(id: _id(), name: c.text.trim()));
      await save();
    }
  }

  Future<void> editFirm(Firm firm) async {
    final c = TextEditingController(text: firm.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Firm'),
        content: TextField(controller: c),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      firm.name = c.text.trim();
      await save();
    }
  }

  Future<void> addClient() async {
    if (data.firms.isEmpty) {
      await addFirm();
      if (data.firms.isEmpty) return;
    }
    final name = TextEditingController();
    final phone = TextEditingController();
    final remark = TextEditingController();
    String firmId = data.firms.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add Client'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Client name')),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'WhatsApp / Phone')),
                DropdownButtonFormField<String>(
                  value: firmId,
                  decoration: const InputDecoration(labelText: 'Firm'),
                  items: data.firms
                      .map((f) => DropdownMenuItem(
                          value: f.id, child: Text(f.name)))
                      .toList(),
                  onChanged: (v) => setD(() => firmId = v!),
                ),
                TextField(
                    controller: remark,
                    decoration: const InputDecoration(labelText: 'Remark')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      data.clients.add(Client(
        id: _id(),
        firmId: firmId,
        name: name.text.trim(),
        phone: phone.text.trim(),
        remark: remark.text.trim(),
      ));
      await save();
    }
  }

  Future<void> editClient(Client c) async {
    final name = TextEditingController(text: c.name);
    final phone = TextEditingController(text: c.phone);
    final remark = TextEditingController(text: c.remark);
    String firmId = c.firmId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Update Client'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name,
                    decoration: const InputDecoration(labelText: 'Client name')),
                TextField(controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                DropdownButtonFormField<String>(
                  value: data.firms.any((f) => f.id == firmId)
                      ? firmId
                      : data.firms.first.id,
                  items: data.firms
                      .map((f) => DropdownMenuItem(
                          value: f.id, child: Text(f.name)))
                      .toList(),
                  onChanged: (v) => setD(() => firmId = v!),
                ),
                TextField(controller: remark,
                    decoration: const InputDecoration(labelText: 'Remark')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Update')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      c.name = name.text.trim();
      c.phone = phone.text.trim();
      c.remark = remark.text.trim();
      c.firmId = firmId;
      await save();
    }
  }

  Future<void> addEntry(Client c) async {
    final work = TextEditingController();
    final amount = TextEditingController();
    final payment = TextEditingController();
    final remark = TextEditingController();
    final date = TextEditingController(
        text: DateTime.now().toIso8601String().substring(0, 10));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Work - ${c.name}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: date,
                  decoration: const InputDecoration(labelText: 'Date')),
              TextField(controller: work,
                  decoration: const InputDecoration(labelText: 'Work / Item')),
              TextField(controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Amount')),
              TextField(controller: payment,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Payment Received')),
              TextField(controller: remark,
                  decoration: const InputDecoration(labelText: 'Remark')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (ok == true) {
      data.entries.add(Entry(
        id: _id(),
        clientId: c.id,
        date: date.text,
        work: work.text.trim(),
        amount: double.tryParse(amount.text) ?? 0,
        payment: double.tryParse(payment.text) ?? 0,
        remark: remark.text.trim(),
      ));
      await save();
    }
  }

  Future<void> clearClient(Client c) async {
    final bal = clientBalance(c.id);
    if (bal <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Balance'),
        content: Text('Add ₹${bal.toStringAsFixed(2)} as received payment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      for (final e in data.entries.where((e) => e.clientId == c.id)) {
        if (e.pending > 0) e.payment += e.pending;
      }
      await save();
    }
  }

  Future<void> backup() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/client_hisab_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonEncode(data.toJson()));
    await Share.shareXFiles([XFile(file.path)],
        text: 'Client Hisab Backup');
  }

  Future<void> restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return;
    try {
      String text;
      if (result.files.single.bytes != null) {
        text = utf8.decode(result.files.single.bytes!);
      } else {
        text = await File(result.files.single.path!).readAsString();
      }
      final restored = AppData.fromJson(jsonDecode(text));
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text(
              'Current data will be replaced by the selected backup. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore')),
          ],
        ),
      );
      if (ok == true) {
        data = restored;
        await save();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup restored successfully')));
          setState(() {});
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid backup file')));
      }
    }
  }

  Future<void> pdfForClient(Client c) async {
    final doc = pw.Document();
    final firm = data.firms
        .where((f) => f.id == c.firmId)
        .map((f) => f.name)
        .firstOrNull ?? '';
    final entries =
        data.entries.where((e) => e.clientId == c.id).toList();
    final balance = clientBalance(c.id);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text('Client Hisab',
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Firm: $firm'),
          pw.Text('Client: ${c.name}'),
          pw.Text('Phone: ${c.phone}'),
          if (c.remark.isNotEmpty) pw.Text('Remark: ${c.remark}'),
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: ['Date', 'Work', 'Amount', 'Payment', 'Pending', 'Remark'],
            data: entries
                .map((e) => [
                      e.date,
                      e.work,
                      e.amount.toStringAsFixed(2),
                      e.payment.toStringAsFixed(2),
                      e.pending.toStringAsFixed(2),
                      e.remark
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 15),
          pw.Text('Current Balance: Rs. ${balance.toStringAsFixed(2)}',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> shareClientPdf(Client c) async {
    final doc = pw.Document();
    final entries =
        data.entries.where((e) => e.clientId == c.id).toList();
    final balance = clientBalance(c.id);
    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Client Hisab - ${c.name}',
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('Phone: ${c.phone}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Date', 'Work', 'Amount', 'Paid', 'Pending'],
            data: entries
                .map((e) => [
                      e.date,
                      e.work,
                      e.amount.toStringAsFixed(2),
                      e.payment.toStringAsFixed(2),
                      e.pending.toStringAsFixed(2)
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Balance: Rs. ${balance.toStringAsFixed(2)}'),
        ],
      ),
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safe(c.name)}_hisab.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Hisab PDF - ${c.name}');
  }

  Future<void> whatsapp(Client c) async {
    if (c.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client WhatsApp number not available')));
      return;
    }
    final bal = clientBalance(c.id);
    final msg = 'Namaste ${c.name}, aapka ₹${bal.toStringAsFixed(2)} payment '
        'pending hai. Kripya payment clear kar dein. Dhanyavaad.';
    final digits = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url =
        Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(msg)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> deleteClient(Client c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Client?'),
        content: Text('Delete ${c.name} and all its work/payment records?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      data.entries.removeWhere((e) => e.clientId == c.id);
      data.clients.removeWhere((e) => e.id == c.id);
      await save();
    }
  }

  Future<void> showClient(Client c) async {
    final entries =
        data.entries.where((e) => e.clientId == c.id).toList();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (_, scroll) => Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    addEntry(c);
                  },
                  icon: const Icon(Icons.add)),
              IconButton(
                  onPressed: () => pdfForClient(c),
                  icon: const Icon(Icons.print)),
              IconButton(
                  onPressed: () => shareClientPdf(c),
                  icon: const Icon(Icons.share)),
            ],
          ),
          body: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  title: Text('Balance: ₹${clientBalance(c.id).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(c.phone.isEmpty ? 'No phone' : c.phone),
                  trailing: clientBalance(c.id) > 0
                      ? FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            clearClient(c);
                          },
                          child: const Text('Clear'))
                      : const Chip(label: Text('CLEAR')),
                ),
              ),
              ...entries.map((e) => Card(
                    child: ListTile(
                      title: Text(e.work.isEmpty ? 'Work' : e.work),
                      subtitle: Text(
                          '${e.date} • Amount ₹${e.amount.toStringAsFixed(2)} • Paid ₹${e.payment.toStringAsFixed(2)}\n'
                          'Pending ₹${e.pending.toStringAsFixed(2)}'
                          '${e.remark.isEmpty ? '' : '\nRemark: ${e.remark}'}'),
                      isThreeLine: true,
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget clientsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search client...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
        Expanded(
          child: filteredClients.isEmpty
              ? const Center(child: Text('No clients'))
              : ListView.builder(
                  itemCount: filteredClients.length,
                  itemBuilder: (_, i) {
                    final c = filteredClients[i];
                    final bal = clientBalance(c.id);
                    final firm = data.firms
                        .where((f) => f.id == c.firmId)
                        .map((f) => f.name)
                        .firstOrNull ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: ListTile(
                        onTap: () => showClient(c),
                        title: Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '$firm\nBalance: ₹${bal.toStringAsFixed(2)}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') editClient(c);
                            if (v == 'delete') deleteClient(c);
                            if (v == 'work') addEntry(c);
                            if (v == 'pdf') pdfForClient(c);
                            if (v == 'share') shareClientPdf(c);
                            if (v == 'wa') whatsapp(c);
                            if (v == 'clear') clearClient(c);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'work',
                                child: Text('Add Work / Payment')),
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'pdf', child: Text('PDF / Print')),
                            const PopupMenuItem(
                                value: 'share', child: Text('Share PDF')),
                            const PopupMenuItem(
                                value: 'wa',
                                child: Text('WhatsApp Reminder')),
                            if (bal > 0)
                              const PopupMenuItem(
                                  value: 'clear', child: Text('Clear Balance')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget firmsPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          onPressed: addFirm,
          icon: const Icon(Icons.add_business),
          label: const Text('Add Firm'),
        ),
        const SizedBox(height: 10),
        ...data.firms.map((f) => Card(
              child: ListTile(
                title: Text(f.name),
                subtitle: Text(
                    '${data.clients.where((c) => c.firmId == f.id).length} clients'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => editFirm(f),
                ),
              ),
            )),
      ],
    );
  }

  Widget balancePage(bool pending) {
    final list = data.clients.where((c) {
      final b = clientBalance(c.id);
      return pending ? b > 0.009 : b <= 0.009;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: Text(pending ? 'Pending Balance' : 'Clear Balance'),
            subtitle: Text('${list.length} clients'),
            trailing: Text(
              '₹${list.fold<double>(0, (s, c) => s + clientBalance(c.id)).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        ...list.map((c) {
          final b = clientBalance(c.id);
          return Card(
            child: ListTile(
              onTap: () => showClient(c),
              title: Text(c.name),
              subtitle: Text(c.phone),
              trailing: Text(
                '₹${b.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pending ? Colors.red : Colors.green),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(child: _stat('Firms', '${data.firms.length}')),
            Expanded(child: _stat('Clients', '${data.clients.length}')),
          ],
        ),
        Row(
          children: [
            Expanded(
                child: _stat('Pending',
                    '₹${totalPending().toStringAsFixed(0)}')),
            Expanded(
                child: _stat(
                    'Clear',
                    '${data.clients.where((c) => clientBalance(c.id) <= .009).length}')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Client Management'),
                subtitle: const Text('Add, update, delete and search clients'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => tab = 1),
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions),
                title: const Text('Pending Balance'),
                onTap: () => setState(() => tab = 2),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Clear Balance'),
                onTap: () => setState(() => tab = 3),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup / Download'),
                onTap: backup,
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore Backup'),
                onTap: restore,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final titles = ['Dashboard', 'Clients', 'Pending', 'Clear', 'Firms'];
    final pages = [
      dashboard(),
      clientsPage(),
      balancePage(true),
      balancePage(false),
      firmsPage()
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          if (tab == 1)
            IconButton(onPressed: addClient, icon: const Icon(Icons.person_add)),
          IconButton(
              onPressed: backup, tooltip: 'Backup', icon: const Icon(Icons.backup)),
          IconButton(
              onPressed: restore,
              tooltip: 'Restore',
              icon: const Icon(Icons.restore)),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
          NavigationDestination(
              icon: Icon(Icons.pending_actions), label: 'Pending'),
          NavigationDestination(
              icon: Icon(Icons.check_circle), label: 'Clear'),
          NavigationDestination(
              icon: Icon(Icons.business), label: 'Firms'),
        ],
      ),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: addClient,
              icon: const Icon(Icons.add),
              label: const Text('Client'),
            )
          : null,
    );
  }
}

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

String _safe(String s) =>
    s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
