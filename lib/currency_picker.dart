import 'package:flutter/material.dart';

import 'app_theme.dart';

class CurrencyOption {
  const CurrencyOption(this.name, this.code);

  final String name;
  final String code;
}

const currencyOptions = <CurrencyOption>[
  CurrencyOption('الليرة السورية', 'SYP'),
  CurrencyOption('الدينار العراقي', 'IQD'),
  CurrencyOption('الجنيه المصري', 'EGP'),
  CurrencyOption('الريال اليمني', 'YER'),
  CurrencyOption('الريال السعودي', 'SAR'),
  CurrencyOption('الدرهم الإماراتي', 'AED'),
  CurrencyOption('الدينار الكويتي', 'KWD'),
  CurrencyOption('الريال القطري', 'QAR'),
  CurrencyOption('الدينار البحريني', 'BHD'),
  CurrencyOption('الريال العُماني', 'OMR'),
  CurrencyOption('الدولار الأمريكي', 'USD'),
  CurrencyOption('اليورو', 'EUR'),
];

Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String current,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AC.surface,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختر العملة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'اختر من العملات الجاهزة أو أضف عملة أخرى.',
                  style: TextStyle(color: AC.muted, fontSize: 11),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: currencyOptions.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      if (index == currencyOptions.length) {
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AC.borderSoft),
                          ),
                          tileColor: AC.card,
                          leading: const Icon(Icons.add_rounded, color: AC.amber),
                          title: const Text(
                            'عملة أخرى',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'أدخل الاسم أو الرمز الذي تريده',
                            style: TextStyle(color: AC.muted, fontSize: 10),
                          ),
                          trailing: const Icon(Icons.chevron_left_rounded, color: AC.hint),
                          onTap: () async {
                            final custom = await _customCurrencyDialog(sheetContext, current);
                            if (custom != null && sheetContext.mounted) {
                              Navigator.pop(sheetContext, custom);
                            }
                          },
                        );
                      }

                      final option = currencyOptions[index];
                      final selected = current.trim().toUpperCase() == option.code;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected ? AC.primary : AC.borderSoft,
                          ),
                        ),
                        tileColor: selected
                            ? AC.primary.withValues(alpha: 0.08)
                            : AC.card,
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AC.primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            option.code,
                            style: const TextStyle(
                              color: AC.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          option.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          option.code,
                          style: const TextStyle(color: AC.muted, fontSize: 10),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded, color: AC.primary)
                            : const Icon(Icons.chevron_left_rounded, color: AC.hint),
                        onTap: () => Navigator.pop(sheetContext, option.code),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<String?> _customCurrencyDialog(BuildContext context, String current) async {
  final controller = TextEditingController(
    text: currencyOptions.any((e) => e.code == current.toUpperCase()) ? '' : current,
  );
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('عملة أخرى'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'اسم أو رمز العملة',
          hintText: 'مثال: JOD أو SEK',
          prefixIcon: Icon(Icons.currency_exchange_rounded),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(dialogContext, value);
          },
          child: const Text('اختيار'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
