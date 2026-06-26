filepath = r'lib/screens/home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../widgets/saved_text_card.dart';\n", '')
content = content.replace("import 'login_screen.dart';\n", '')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Unused imports removed.')
