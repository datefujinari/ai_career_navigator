import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

// -------------------------------
// エントリポイント：CupertinoApp（iOSライク）
// -------------------------------
void main() => runApp(const CareerApp());

class CareerApp extends StatelessWidget {
  const CareerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

// -------------------------------
// ホーム画面：入力 → 分析実行 → 結果表示
// -------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 入力テキストコントローラ
  final meCtrl = TextEditingController(); // 自分のGitHubユーザー名
  final targetCtrl = TextEditingController(); // 目標(ユーザー名 or 技術キーワード)

  // 画面状態
  bool loading = false; // 分析中スピナーのON/OFF
  List<String> roadmap = []; // 生成されたロードマップ（行ごと）

  // あなたのデプロイしたHTTP関数のURL（後で置き換え）
  static const endpoint = String.fromEnvironment(
    'API_ENDPOINT',
    defaultValue: 'http://localhost:8080', // ローカル動作時
  );

  // -------------------------------
  // 分析を実行：サーバへPOST → レスポンス(JSON)受取
  // -------------------------------
  Future<void> runAnalyze() async {
    final me = meCtrl.text.trim();
    final target = targetCtrl.text.trim();
    if (me.isEmpty || target.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('入力不足'),
          content: Text('GitHubユーザー名と目標を入力してください'),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      roadmap = [];
    });

    // モックデータでUI確認用
    // await Future.delayed(const Duration(seconds: 2)); // ローディング状態を確認

    // setState(() {
    //   roadmap = [
    //     'Reactの基本を学習する',
    //     'TypeScriptの型システムを理解する',
    //     'Node.jsでバックエンドAPIを作成する',
    //     'PostgreSQLデータベースを学ぶ',
    //     'Dockerでコンテナ化する',
    //     'AWS/GCPのクラウドサービスを学習する',
    //     'CI/CDパイプラインを構築する',
    //     'テスト駆動開発(TDD)を実践する',
    //   ];
    //   loading = false;
    // });

    try {
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': me, 'target': target}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        // サーバが "roadmap" を箇条書きの配列で返す前提（後述のPythonと合わせる）
        final List items = data['roadmap'] ?? [];
        setState(() {
          roadmap = items.map((e) => e.toString()).toList();
        });
      } else {
        setState(() {
          roadmap = ['エラー: ${res.statusCode} ${res.body}'];
        });
      }
    } catch (e) {
      setState(() {
        roadmap = ['通信エラー: $e'];
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('AIキャリアパスナビ（MVP）'),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ListView(
              children: [
                const Text(
                  '1) あなたのGitHubユーザー名',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: meCtrl,
                  placeholder: '例: octocat',
                  clearButtonMode: OverlayVisibilityMode.editing,
                ),
                const SizedBox(height: 16),
                const Text(
                  '2) 目標（ユーザー名 or 技術キーワード）',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: targetCtrl,
                  placeholder: '例: deno開発者 / rust backend engineer / torvalds',
                  clearButtonMode: OverlayVisibilityMode.editing,
                ),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  onPressed: loading ? null : runAnalyze,
                  child: const Text('分析する'),
                ),
                const SizedBox(height: 24),
                if (roadmap.isNotEmpty)
                  const Text(
                    '学習ロードマップ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                ...roadmap.map(
                  (line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
            if (loading)
              const Center(child: CupertinoActivityIndicator(radius: 16)),
          ],
        ),
      ),
    );
  }
}
