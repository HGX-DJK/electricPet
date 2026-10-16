import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';

/// 萌宠魔法衣橱换装面板 (支持 8 大纯种猫咪品种切换、头部帽子、颈部配饰三 Tab 架构)
class WardrobeDialog extends StatefulWidget {
  final PetModel model;
  final bool isNight;

  const WardrobeDialog({
    super.key,
    required this.model,
    this.isNight = false,
  });

  @override
  State<WardrobeDialog> createState() => _WardrobeDialogState();
}

class _WardrobeDialogState extends State<WardrobeDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 头部帽子装饰库
  static const List<Map<String, String>> _headDecos = [
    {'id': 'none', 'name': '无帽子', 'icon': '🚫', 'desc': '保持自然清爽原生小脑瓜'},
    {'id': 'crown', 'name': '璀璨金冠', 'icon': '👑', 'desc': '华丽三峰黄金皇冠，镶嵌红绿蓝三色宝石'},
    {'id': 'wizard_hat', 'name': '魔法巫师帽', 'icon': '🧙‍♂️', 'desc': '深邃星空尖顶巫师帽，缀有灵动小金星'},
    {'id': 'straw_hat', 'name': '田园草帽', 'icon': '👒', 'desc': '暖阳编织宽檐草帽，配法式复古绯红丝带'},
    {'id': 'sailor_cap', 'name': '蔚蓝水手帽', 'icon': '⚓', 'desc': '帅气挺括水手无檐帽，海军蓝条纹与金徽章'},
  ];

  // 颈部配饰挂件库
  static const List<Map<String, String>> _neckDecos = [
    {'id': 'none', 'name': '无配饰', 'icon': '🚫', 'desc': '摘下颈部挂件，舒适自在'},
    {'id': 'bell', 'name': '经典金铃铛', 'icon': '🔔', 'desc': '赤红如意项圈配轻晃纯金小铃铛'},
    {'id': 'ribbon', 'name': '俏皮蝴蝶结', 'icon': '🎀', 'desc': '甜美草莓粉双翼缎带蝴蝶结'},
    {'id': 'bowtie', 'name': '英伦绅士领结', 'icon': '🤵', 'desc': '深邃午夜蓝双层领结配雅致金扣'},
    {'id': 'scarf', 'name': '暖冬红围巾', 'icon': '🧣', 'desc': '冬日暖绒绯红长围巾配纯白流苏'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final isNight = widget.isNight;

    final bgColor = isNight ? const Color(0xFF1E1B4B) : Colors.white;
    final titleColor = isNight ? Colors.white : const Color(0xFF1E293B);
    final subColor = isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isNight ? const Color(0xFF2E2A68) : const Color(0xFFF8FAFC);
    final borderColor = isNight ? const Color(0xFF4338CA) : const Color(0xFFE2E8F0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.64,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽指示把手
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 标题与关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👗', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '波可的魔法衣橱',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF332D73) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 18, color: subColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '即时变身与换装，轻触上方波可即可实时更新 🐾',
            style: TextStyle(fontSize: 11.5, color: subColor),
          ),
          const SizedBox(height: 12),

          // 三分类 Tab 栏
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isNight ? const Color(0xFF131131) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(19),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: const Color(0xFFA855F7),
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: subColor,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: '🐱 猫咪品种'),
                Tab(text: '🎩 头部帽子'),
                Tab(text: '🎀 颈部挂件'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab 内容展示区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBreedTab(model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildHeadDecoTab(model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildNeckDecoTab(model, isNight, cardBg, borderColor, titleColor, subColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1. 猫咪名猫品种选择 Tab
  Widget _buildBreedTab(
    PetModel model,
    bool isNight,
    Color cardBg,
    Color borderColor,
    Color titleColor,
    Color subColor,
  ) {
    // 过滤展示 8 大特色纯种猫咪品种 (排重 cat_white)
    final skins = PetModel.availableSkins.values
        .where((s) => s.id != 'cat_white')
        .toList();

    final currentSkin = model.currentSkin;

    return Column(
      children: [
        // 品种横向滑动选择列表
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: skins.length,
            itemBuilder: (context, index) {
              final skin = skins[index];
              final isSelected = (model.skinId == skin.id);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    model.setSkin(skin.id);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 96,
                  margin: const EdgeInsets.only(right: 10, top: 2, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                        : cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFA855F7) : borderColor,
                      width: isSelected ? 2.2 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFA855F7).withOpacity(0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 品种头像与配色双色环
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(skin.primaryColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: Color(skin.secondaryColor), width: 3.2),
                              boxShadow: const [
                                BoxShadow(color: Color(0x18000000), blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Center(
                              child: Text(skin.icon, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.28),
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        skin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                              : titleColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        skin.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected
                              ? (isNight ? const Color(0xFFD8B4FE) : const Color(0xFFA855F7))
                              : subColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // 选中品种的详细特征图鉴卡片 (Profile Card)
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isNight ? const Color(0xFF262153) : const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isNight ? const Color(0xFF6B21A8) : const Color(0xFFE9D5FF),
                width: 1.2,
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(currentSkin.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSkin.breed,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA855F7).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentSkin.title,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA855F7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 色板宝石小圆圈
                      Row(
                        children: [
                          _buildColorDot(currentSkin.primaryColor, '毛色底色'),
                          const SizedBox(width: 4),
                          _buildColorDot(currentSkin.secondaryColor, '斑纹重点色'),
                          const SizedBox(width: 4),
                          _buildColorDot(currentSkin.eyeColor, '瞳孔宝石色'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentSkin.desc,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF1E1944) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFA855F7)),
                        const SizedBox(width: 5),
                        Text(
                          '当前生效：波可已变身为${currentSkin.name}，具备专属五官斑纹与毛色',
                          style: TextStyle(
                            fontSize: 11,
                            color: isNight ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. 头部帽子 Tab
  Widget _buildHeadDecoTab(
    PetModel model,
    bool isNight,
    Color cardBg,
    Color borderColor,
    Color titleColor,
    Color subColor,
  ) {
    final currentHead = model.decorations['head'] ?? 'none';

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _headDecos.length,
      itemBuilder: (context, index) {
        final item = _headDecos[index];
        final id = item['id']!;
        final isSelected = (currentHead == id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              model.setDecoration('head', id);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                  : cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFA855F7) : borderColor,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withOpacity(0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                              : titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['desc']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? (isNight ? const Color(0xFFD8B4FE) : const Color(0xFFA855F7))
                              : subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFFA855F7), size: 20)
                else
                  Icon(Icons.radio_button_unchecked, color: subColor.withOpacity(0.5), size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 3. 颈部配饰 Tab
  Widget _buildNeckDecoTab(
    PetModel model,
    bool isNight,
    Color cardBg,
    Color borderColor,
    Color titleColor,
    Color subColor,
  ) {
    final currentNeck = model.decorations['neck'] ?? 'none';

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _neckDecos.length,
      itemBuilder: (context, index) {
        final item = _neckDecos[index];
        final id = item['id']!;
        final isSelected = (currentNeck == id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              model.setDecoration('neck', id);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                  : cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFA855F7) : borderColor,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withOpacity(0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                              : titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['desc']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? (isNight ? const Color(0xFFD8B4FE) : const Color(0xFFA855F7))
                              : subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFFA855F7), size: 20)
                else
                  Icon(Icons.radio_button_unchecked, color: subColor.withOpacity(0.5), size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorDot(int colorHex, String label) {
    return Tooltip(
      message: label,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Color(colorHex),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}
