# 2.5.6
1. [x] 钝器砍舌
2. [x] 尸潮
    * [x] survivor_limit (救援关刷药问题，出门后限制) 无效尸潮总数量不减，一波出的数量很少，不过对于普通关卡有作用
    * [x] 改 versus2coop
    * [x] left4dhooks 控制 mob 数量
        >/**  
        >\* @brief Called whenever CDirector::OnMobRushStart(void) is invoked  
        >\* @remarks called on random hordes, mini and finale hordes, and boomer hordes, causes Zombies to attack  
        >\*			Not called on "z_spawn mob", hook the console command and check arguments to catch plugin mobs  
        >\*			This function is used to reset the Director's natural horde timer.  
        >\*  
        >\* @return				Plugin_Handled to block, Plugin_Continue otherwise  
        >\*/  
        >forward Action L4D_OnMobRushStart();  
  
        >/**  
        >\* @brief Called whenever ZombieManager::SpawnMob(int) is invoked  
        >\* @remarks called on natural hordes & z_spawn mob, increases Zombie Spawn  
        >\*			Queue, triggers player OnMobSpawned (vocalizations), sets horde  
        >\*			direction, and plays horde music.  
        >\*  
        >\* @param amount		Amount of Zombies to add to Queue  
        >\*  
        >\* @return				Plugin_Handled to block, Plugin_Changed to use overwritten values from plugin, Plugin_Continue otherwise  
        >\*/  
        >forward Action L4D_OnSpawnMob(int &amount);  
    * 实测发现是 z_mega_mob_size 在更换为战役模式时被重写成 50
    * C5M5 之类的无限尸潮通过 L4D_OnSpawnMob 事件阻止掉刷新频率过快的尸潮，mob 似乎不受 z_common_limit 影响
    * 提高小僵尸数量
3. [ ] Stripper
4. [x] tank 人数血量
5. [x] z_vesus_xxxx_limit
6. [x] tank 攻击选择
7. [x] tank 长拳
8. [x] c3m4包
9. [x] no deadstop cfg
10. [ ] 重复换图
11. [ ] 模式重写的参数
12. [x] tz 菜单补全