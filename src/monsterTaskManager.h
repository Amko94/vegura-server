#ifndef VEGURA_SERVER_MONSTERTASKMANAGER_H
#define VEGURA_SERVER_MONSTERTASKMANAGER_H
#include <cstdint>
#include <string>
#include <vector>
#include <ctime>

struct TaskMonster {
    std::string name;
    uint16_t lookType;
};


struct MonsterTaskDefinition {
    uint32_t id;
    std::string name;
    uint8_t category;
    uint32_t experience;

    std::vector<TaskMonster> monsters;
};

struct PlayerMonsterTask {
    uint32_t id;
    uint32_t playerId;
    uint32_t taskId;
    uint32_t amount;
    uint32_t progress;
    bool paused;
    bool finished;
    bool active;
    std::time_t startTime;
    std::time_t endTime;
    uint64_t rewardGold;
    uint64_t rewardExperience;
    uint32_t rewardTaskPoints;
};

struct StartTaskModel {
    uint32_t playerId;
    uint32_t taskId;
    uint32_t amount;
};

enum class RewardType : uint8_t {
    Gold,
    Experience,
    Split
};

enum class TaskCategory : uint8_t {
    Low = 1,
    Medium = 2,
    High = 3,
    VeryHigh = 4
};

enum class ClaimRewardStatus {
    Success,
    TaskNotFound,
    NotFinished,
    InvalidRewardType,
    DbError
};

struct ClaimRewardResult {
    ClaimRewardStatus status = ClaimRewardStatus::DbError;

    uint64_t gold = 0;
    uint64_t experience = 0;
    uint32_t taskPoints = 0;

    uint32_t taskId = 0;
    uint32_t amount = 0;
};


class MonsterTaskManager {
public:
    bool loadMonsterTaskDefinitionList();

    bool hasActiveTask(uint32_t playerId);

    bool startTask(StartTaskModel &model);

    bool pauseTask(uint32_t playerId, uint32_t taskId);

    bool resumeTask(uint32_t playerId, uint32_t taskId);

    bool cancelTask(uint32_t playerId, uint32_t taskId);

    bool updateTaskProgress(uint32_t playerId, uint32_t taskId, uint32_t kills);

    ClaimRewardResult claimReward(
        uint32_t playerId,
        uint32_t playerTaskId,
        RewardType rewardType
    );


    PlayerMonsterTask getActiveTask(uint32_t playerId);

    const std::vector<MonsterTaskDefinition> &getMonsterTaskDefinitionList() const;

    std::vector<PlayerMonsterTask> getPlayerMonsterTasks(uint32_t playerId);

    MonsterTaskDefinition getTaskDefinitionById(uint32_t taskId);

    PlayerMonsterTask getPlayerTaskById(uint32_t playerId, uint32_t taskId);

private:
    std::vector<MonsterTaskDefinition> monsterTaskDefinitionList;

    uint32_t calculateGoldReward(uint32_t experience, uint32_t amount, TaskCategory category);

    uint64_t calculateExperienceReward(uint32_t amount, uint32_t experience);

    uint32_t calculateTaskPointsReward(uint32_t amount, uint32_t experience, TaskCategory category);
};


#endif
