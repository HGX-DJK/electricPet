import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';
import 'gacha_dialog.dart';

/// 萌宠魔法衣橱换装面板 (支持 8 大纯种猫咪品种切换、头部、面部、颈部、背部、手持、小窝 7 Tab 架构)
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

  // 1. 头部帽子装饰库
  static const List<Map<String, String>> _headDecos = [
    {'id': 'none', 'name': '无帽子', 'icon': '🚫', 'desc': '保持自然清爽原生小脑瓜'},
    {'id': 'band_sport', 'name': '元气运动发带', 'icon': '🏃', 'desc': '运动喵神装：红白运动双条纹，中央缀金色闪电徽章'},
    {'id': 'gold_crown_sparkle', 'name': '璀璨星辉皇冠', 'icon': '✨', 'desc': '羁绊4阶专属：五峰纯金大王冠，环绕耀目星尘', 'minStage': '4'},
    {'id': 'crown', 'name': '璀璨金冠', 'icon': '👑', 'desc': '华丽三峰黄金皇冠，镶嵌红绿蓝三色宝石'},
    {'id': 'wizard_hat', 'name': '魔法巫师帽', 'icon': '🧙‍♂️', 'desc': '深邃星空尖顶巫师帽，缀有灵动小金星'},
    {'id': 'straw_hat', 'name': '田园草帽', 'icon': '👒', 'desc': '暖阳编织宽檐草帽，配法式复古绯红丝带'},
    {'id': 'sailor_cap', 'name': '蔚蓝水手帽', 'icon': '⚓', 'desc': '帅气挺括水手无檐帽，海军蓝条纹与金徽章'},
  ];

  // 2. 面部眼镜装饰库
  static const List<Map<String, String>> _faceDecos = [
    {'id': 'none', 'name': '无面饰', 'icon': '🚫', 'desc': '摘下面饰，露出清秀灵动大眼睛'},
    {'id': 'glasses_black', 'name': '经典黑框平光镜', 'icon': '🤓', 'desc': '极客文艺黑框眼镜，散发学者睿智气质'},
    {'id': 'sunglasses_cool', 'name': '炫酷飞行员墨镜', 'icon': '😎', 'desc': '金边黑超渐变反光镜片，气场全开'},
    {'id': 'hacker_viser', 'name': '赛博战术全息目镜', 'icon': '🕶️', 'desc': '黑客喵专属神装：全息数据扫描线与绿光HUD准星'},
  ];

  // 3. 颈部配饰挂件库
  static const List<Map<String, String>> _neckDecos = [
    {'id': 'none', 'name': '无配饰', 'icon': '🚫', 'desc': '摘下颈部挂件，舒适自在'},
    {'id': 'royal_cape', 'name': '皇家丝绒披风', 'icon': '🦸‍♂️', 'desc': '羁绊3阶专属：高贵深紫红丝绒小斗篷，缀纯金流光包边', 'minStage': '3'},
    {'id': 'bell', 'name': '经典金铃铛', 'icon': '🔔', 'desc': '赤红如意项圈配轻晃纯金小铃铛'},
    {'id': 'ribbon', 'name': '俏皮蝴蝶结', 'icon': '🎀', 'desc': '甜美草莓粉双翼缎带蝴蝶结'},
    {'id': 'bowtie', 'name': '英伦绅士领结', 'icon': '🤵', 'desc': '深邃午夜蓝双层领结配雅致金扣'},
    {'id': 'scarf', 'name': '暖冬红围巾', 'icon': '🧣', 'desc': '冬日暖绒绯红长围巾配纯白流苏'},
  ];

  // 4. 背部装扮库
  static const List<Map<String, String>> _backDecos = [
    {'id': 'none', 'name': '无背饰', 'icon': '🚫', 'desc': '收起背饰，自在伸展小身躯'},
    {'id': 'cape_cyber', 'name': '赛博霓虹披风', 'icon': '🦸‍♂️', 'desc': '暗曜战术织物，流淌天青与粉紫数字电路光纹'},
    {'id': 'wings_angel', 'name': '圣洁天使羽翼', 'icon': '🪽', 'desc': '纯白发光羽翼，微风轻拂轻盈振翅'},
    {'id': 'shell_turtle', 'name': '萌趣硬壳龟包', 'icon': '🐢', 'desc': '六边形天然翠绿小龟壳，呆萌可爱'},
  ];

  // 5. 前爪手持道具库
  static const List<Map<String, String>> _handDecos = [
    {'id': 'none', 'name': '空着小爪', 'icon': '🚫', 'desc': '空手放松，双爪撑地'},
    {'id': 'keyboard_rgb', 'name': 'RGB 机械键盘', 'icon': '⌨️', 'desc': '黑客喵专属神器：动态彩虹走马灯背光机械键帽'},
    {'id': 'teaser_laser', 'name': '全息激光逗猫棒', 'icon': '🪄', 'desc': '高科技逗猫棒，竿头射出全息粒子星辉'},
    {'id': 'coffee_cyber', 'name': '极客黑客冷萃杯', 'icon': '☕', 'desc': '赛博天青隔热杯套，升腾数字化二进制冷气'},
    {'id': 'gamepad_retro', 'name': '8-bit 复古掌机', 'icon': '🕹️', 'desc': '经典复古掌上游戏机，荧光绿像素液晶屏'},
    {'id': 'dumbbell_power', 'name': '赛博能量哑铃', 'icon': '🏋️', 'desc': '运动喵专属力量训练器，两端环绕充能天青光环'},
  ];

  // 6. 赛博小窝场景库
  static const List<Map<String, String>> _habitatDecos = [
    {'id': 'default', 'name': '原初极简空间', 'icon': '⚪', 'desc': '纯粹清爽，专注观察波可的真实动态'},
    {'id': 'neon_matrix', 'name': '暗夜霓虹极客房', 'icon': '💻', 'desc': '绿/青 Matrix 数字代码雨，透视全息地面网格'},
    {'id': 'retro_arcade', 'name': '复古像素电玩厅', 'icon': '🕹️', 'desc': 'Synthwave 8-bit 星辉与粉紫扫描线脉冲'},
    {'id': 'summer_beach', 'name': '夏日海滩暖阳', 'icon': '🏖️', 'desc': '温柔夕阳金晕，轻缓起伏的碧波浪花'},
    {'id': 'zen_tatami', 'name': '佛系禅意蒲团室', 'icon': '🍵', 'desc': '厚实蔺草蒲团软垫，微风摇曳飘舞的粉嫩樱花'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
      height: MediaQuery.of(context).size.height * 0.72,
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

          // 标题与快捷功能按键 (盲盒扭蛋、随机混搭、关闭)
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
              Row(
                children: [
                  // 🎲 随机混搭穿戴
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final rand = math.Random();
                      setState(() {
                        final heads = _headDecos.map((e) => e['id']!).toList();
                        final faces = _faceDecos.map((e) => e['id']!).toList();
                        final necks = _neckDecos.map((e) => e['id']!).toList();
                        final backs = _backDecos.map((e) => e['id']!).toList();
                        final hands = _handDecos.map((e) => e['id']!).toList();
                        model.setDecoration('head', heads[rand.nextInt(heads.length)]);
                        model.setDecoration('face', faces[rand.nextInt(faces.length)]);
                        model.setDecoration('neck', necks[rand.nextInt(necks.length)]);
                        model.setDecoration('back', backs[rand.nextInt(backs.length)]);
                        model.setDecoration('hand', hands[rand.nextInt(hands.length)]);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎲 灵感迸发！已随机换上一套全新混搭神装~ ✨'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF332D73) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎲', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 3),
                          Text('混搭', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: subColor)),
                        ],
                      ),
                    ),
                  ),

                  // 🔮 赛博能量盲盒入口
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => GachaDialog(
                          model: widget.model,
                          onUpdated: () => setState(() {}),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔮', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 3),
                          Text('盲盒', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                  // 关闭按钮
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
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '5大插槽神装混搭与赛博小窝，轻触即可即时生效 🐾',
            style: TextStyle(fontSize: 11.5, color: subColor),
          ),
          const SizedBox(height: 12),

          // 7 大分类可滑动 Tab 栏
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isNight ? const Color(0xFF131131) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(19),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
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
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: '🐱 品种'),
                Tab(text: '🎩 头部'),
                Tab(text: '👓 面部'),
                Tab(text: '🎀 颈部'),
                Tab(text: '🦸‍♂️ 背部'),
                Tab(text: '🪄 手持'),
                Tab(text: '🏠 小窝'),
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
                _buildDecoTab('head', _headDecos, model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildDecoTab('face', _faceDecos, model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildDecoTab('neck', _neckDecos, model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildDecoTab('back', _backDecos, model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildDecoTab('hand', _handDecos, model, isNight, cardBg, borderColor, titleColor, subColor),
                _buildHabitatTab(model, isNight, cardBg, borderColor, titleColor, subColor),
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

                  // 专属骨骼体态与外貌特征标签组
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: _getBreedTags(currentSkin.id).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isNight ? const Color(0xFF3B2F7E) : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isNight ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isNight ? const Color(0xFFDDD6FE) : const Color(0xFF6D28D9),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF1E1944) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFA855F7)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '专属形态已生效：脸型、耳型、体型、尾巴已全面切换为${currentSkin.name}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isNight ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8),
                            ),
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

  /// 通用部位装扮选择 Tab (头部、面部、颈部、背部、手持)
  Widget _buildDecoTab(
    String slot,
    List<Map<String, String>> decos,
    PetModel model,
    bool isNight,
    Color cardBg,
    Color borderColor,
    Color titleColor,
    Color subColor,
  ) {
    final currentVal = model.decorations[slot] ?? 'none';

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: decos.length,
      itemBuilder: (context, index) {
        final item = decos[index];
        final id = item['id']!;
        final isSelected = (currentVal == id);
        final minStageStr = item['minStage'];
        final minStage = minStageStr != null ? int.parse(minStageStr) : 0;
        final currentStage = (model.intimacyBondInfo['stage'] as int?) ?? 1;
        final isLocked = minStage > currentStage;

        return GestureDetector(
          onTap: () {
            if (isLocked) {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔒 专属装扮：亲密度羁绊需达到第 $minStage 阶解锁！多与波可互动吧~ 💖'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              );
              return;
            }
            HapticFeedback.lightImpact();
            setState(() {
              model.setDecoration(slot, id);
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
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '阶$minStage解锁',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  )
                else if (isSelected)
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

  /// 7. 赛博小窝场景 Tab
  Widget _buildHabitatTab(
    PetModel model,
    bool isNight,
    Color cardBg,
    Color borderColor,
    Color titleColor,
    Color subColor,
  ) {
    final currentHabitat = model.habitat;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _habitatDecos.length,
      itemBuilder: (context, index) {
        final item = _habitatDecos[index];
        final id = item['id']!;
        final isSelected = (currentHabitat == id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              model.setHabitat(id);
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

  List<String> _getBreedTags(String skinId) {
    switch (skinId) {
      case 'cat_ragdoll':
        return ['🪶 蓬松羽毛大尾巴', '☁️ 华丽胸毛领圈', '✨ 侧脸爆毛与仙气耳毛', '🎭 海豹八字开脸'];
      case 'cat_siamese':
        return ['🦇 高耸挺拔大尖耳', '📐 东方修长楔形V脸', '🎋 灵巧细鞭尾', '☕ 焦糖重点色糊脸'];
      case 'cat_british_blue':
        return ['🥟 饱满发腮大包子脸', '🐾 矮胖五短厚实躯干', '🦦 粗圆水獭尾', '🪙 璀璨铜金双眸'];
      case 'cat_orange':
        return ['🥐 大橘为重软萌肚腩', '🐯 侧腹与尾部环形虎斑', '🐾 肥嘟嘟厚脚爪', '🥐 阳光圆圆大脑袋'];
      case 'cat_persian_white':
        return ['🦁 飘逸如狮颈部鬃毛', '💎 鸳鸯异瞳双色眼', '🪶 纯白蓬松羽毛尾', '❄️ 仙气耳内饰毛'];
      case 'cat_calico':
        return ['☯️ 一橘一黑双色阴阳耳', '🎨 三色不规则大色块拼接', '🍀 招财祈福民间吉猫'];
      case 'cat_american_tabby':
        return ['Ⓜ️ 额头经典虎斑M纹', '🌀 侧腹大理石回旋涡纹', '🦝 浣熊环形斑纹尾', '🏃 敏捷精悍猎手身材'];
      case 'cat_black':
        return ['🖤 曜石纯黑流线体态', '🧦 踏雪寻梅纯白手套爪', '✨ 夜光冷白长胡须', '🌕 澄澈金色星芒双眸'];
      default:
        return ['🐾 纯洁灵动小萌宠'];
    }
  }
}
