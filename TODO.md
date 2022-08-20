# 2.6.x
1. [x] 生还与特感人数平衡时，阻止玩家进入服务器自动加入生还
2. [x] 人挤人
3. [x] 双人难度降低
4. [x] 自动发药延迟
5. [ ] ~~删除地图药，实体名称为 weapon_spawn，连带着武器一起删~~，考虑使用 weapon_rules 
6. [x] 近战刀牛伤害 325 -> 350
7. [x] 插件锁定 cvar 
8. [x] 关底 mvp 显示
9. [ ] 声音重复
10. [x] 更新 Sourcemod 至 1.11.0.6825，同 Zonemod
11. [ ] 刷特卡
12. [x] 终章换图
13. [x] Zonemod 地图改动，救援关刷药点要改
14. [x] awp 为什么只刷一把，用 stripper 替换正常
15. [x] pill_passer GivePlayerItem
16. [x] zonemod 2.7 weapon
17. [x] 偶然刷包（编译器版本问题）
18. [ ] Tank 默认不连跳？
19. [x] vote configs 加上 type
20. [x] 生还游戏中跑路


# 2.5.6
1. [x] 钝器砍舌
2. [x] 尸潮
    * [x] survivor_limit (救援关刷药问题，出门后限制) 无效尸潮总数量不减，一波出的数量很少，不过对于普通关卡有作用
    * [x] 改 versus2coop
    * [x] left4dhooks 控制 mob 数量
        >/**
        \* @brief Called whenever CDirector::OnMobRushStart(void) is invoked
        \* @remarks called on random hordes, mini and finale hordes, and boomer hordes, causes Zombies to attack
        \*			Not called on "z_spawn mob", hook the console command and check arguments to catch plugin mobs
        \*			This function is used to reset the Director's natural horde timer.
        \*
        \* @return				Plugin_Handled to block, Plugin_Continue otherwise
        \*/
        forward Action L4D_OnMobRushStart();

        >/**
        \* @brief Called whenever ZombieManager::SpawnMob(int) is invoked
        \* @remarks called on natural hordes & z_spawn mob, increases Zombie Spawn
        \*			Queue, triggers player OnMobSpawned (vocalizaStions), sets horde
        \*			direction, and plays horde music.
        \*
        \* @param amount		Amount of Zombies to add to Queue
        \*
        \* @return				Plugin_Handled to block, Plugin_Changed to use overwritten values from plugin, Plugin_Continue otherwise
        \*/
        forward Action L4D_OnSpawnMob(int &amount);
    * 实测发现是 z_mega_mob_size 在更换为战役模式时被重写成 50
    * C5M5 之类的无限尸潮通过 L4D_OnSpawnMob 事件阻止掉刷新频率过快的尸潮，mob 似乎不受 z_common_limit 影响
    * 提高小僵尸数量
3. [x] Stripper
4. [x] tank 人数血量
5. [x] z_vesus_xxxx_limit
6. [x] tank 攻击选择
7. [x] tank 长拳
8. [x] c3m4包
9. [x] no deadstop cfg
10. [ ] 重复换图
11. [x] 模式重写的参数
12. [x] tz 菜单补全
13. [x] C7 删除地图的导演系统脚本
