import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/app_shell.dart';
import '../widgets/ui/app_card.dart';

/// 환급액 사용처 — 지역 가맹점 + 특산물 온라인몰 연결.
/// 디자인: halftrip-design/online-mall.html 리스트 스타일.
class RefundUsageScreen extends StatelessWidget {
  const RefundUsageScreen({
    super.key,
    required this.regionId,
    required this.residence,
  });

  final int regionId;
  final String residence;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return AppShell(
      title: '환급액 사용처',
      modeName: controller.modeName,
      child: FutureBuilder(
        future: controller.repository.getRegionDetail(regionId, residence: residence),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _SectionTitle('${detail.region.name} 오프라인 가맹점'),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final merchant in detail.merchants)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.surf,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.storefront_outlined,
                                  size: 20, color: AppColors.p600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    merchant.name,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink9,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${merchant.category} · ${merchant.address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle('특산물 온라인몰'),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final mall in detail.onlineMalls)
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse(mall.mallUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.surf,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined,
                                    size: 20, color: AppColors.p600),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mall.name,
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink9,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      mall.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded,
                                  size: 17, color: AppColors.ink4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.ink9,
        letterSpacing: -0.5,
      ),
    );
  }
}
