#include "otpch.h"
#include "monsterTaskManager.h"
#include "database.h"
#include "player.h"
#include "pugixml.hpp"
#include "tools.h"
#include "pugicast.h"

bool MonsterTaskManager::loadMonsterTaskDefinitionList() {
    monsterTaskDefinitionList.clear();

    pugi::xml_document doc;
    pugi::xml_parse_result result = doc.load_file("data/XML/tasks.xml");
    if (!result) {
        printXMLError(
            "Error - MonsterTaskManager::loadMonsterTaskDefinitions",
            "data/XML/tasks.xml",
            result
        );
        return false;
    }

    for (auto taskNode: doc.child("tasks").children("task")) {
        MonsterTaskDefinition def;

        pugi::xml_attribute attr;

        if ((attr = taskNode.attribute("id"))) {
            def.id = pugi::cast<uint32_t>(attr.value());
        }

        if ((attr = taskNode.attribute("name"))) {
            def.name = attr.as_string();
        }

        if ((attr = taskNode.attribute("category"))) {
            def.category = pugi::cast<uint8_t>(attr.value());
        }

        if ((attr = taskNode.attribute("experience"))) {
            def.experience = pugi::cast<uint32_t>(attr.value());
        }

        for (auto monsterNode: taskNode.child("monsters").children("monster")) {
            TaskMonster monster;

            if ((attr = monsterNode.attribute("name"))) {
                monster.name = attr.as_string();
            }

            if ((attr = monsterNode.attribute("lookType"))) {
                monster.lookType = pugi::cast<uint16_t>(attr.value());
            }

            def.monsters.push_back(monster);
        }

        monsterTaskDefinitionList.push_back(def);
    }

    return true;
}


bool MonsterTaskManager::hasActiveTask(uint32_t playerId) {
    DBResult_ptr result = Database::getInstance()->storeQuery(
        "SELECT 1 FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND Paused = 0 AND Active = 1 LIMIT 1"
    );

    return result != nullptr;
}

bool MonsterTaskManager::startTask(StartTaskModel &model) {
    MonsterTaskDefinition taskDef = getTaskDefinitionById(model.taskId);

    if (taskDef.id == 0) {
        return false;
    }

    uint32_t amount = model.amount;
    if (amount < 50 || amount > 1000) {
        return false;
    }

    TaskCategory category = static_cast<TaskCategory>(taskDef.category);

    uint32_t totalGold =
            calculateGoldReward(taskDef.experience, amount, category);

    uint64_t totalExp =
            calculateExperienceReward(amount, taskDef.experience);

    uint32_t totalTaskPoints =
            calculateTaskPointsReward(amount, taskDef.experience, category);

    Database *db = Database::getInstance();
    std::ostringstream query;

    query
            << "INSERT INTO PlayerTasks ("
            << "PlayerId, TaskId, Amount, Progress, Paused, Finished, Active, "
            << "StartTime, EndTime, Reward_Experience, Reward_Gold, Reward_TaskPoints"
            << ") VALUES ("
            << model.playerId << ", "
            << model.taskId << ", "
            << amount << ", "
            << "0, 0, 0, 1, "
            << "NOW(), NULL, "
            << totalExp << ", "
            << totalGold << ", "
            << totalTaskPoints
            << ")";

    return db->executeQuery(query.str());
}

bool MonsterTaskManager::pauseTask(uint32_t playerId, uint32_t taskId) {
    Database *db = Database::getInstance();

    DBResult_ptr result = db->storeQuery(
        "SELECT Id, Finished "
        "FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND TaskId = " + std::to_string(taskId) +
        " AND Active = 1 AND Paused = 0 "
        "LIMIT 1"
    );

    if (!result) {
        return false;
    }

    uint32_t playerTaskId = result->getNumber<uint32_t>("Id");
    bool finished = result->getNumber<uint32_t>("Finished") != 0;

    if (finished) {
        return false;
    }

    return db->executeQuery(
        "UPDATE PlayerTasks SET Paused = 1 WHERE Id = " +
        std::to_string(playerTaskId)
    );
}

bool MonsterTaskManager::resumeTask(uint32_t playerId, uint32_t taskId) {
    Database *db = Database::getInstance();

    DBResult_ptr activeCheck = db->storeQuery(
        "SELECT 1 FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND Active = 1 AND Paused = 0 "
        "LIMIT 1"
    );

    if (activeCheck) {
        return false;
    }

    DBResult_ptr result = db->storeQuery(
        "SELECT Id "
        "FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND TaskId = " + std::to_string(taskId) +
        " AND Finished = 0 AND Paused = 1 "
        "LIMIT 1"
    );

    if (!result) {
        return false;
    }

    uint32_t playerTaskId = result->getNumber<uint32_t>("Id");

    return db->executeQuery(
        "UPDATE PlayerTasks SET Paused = 0 WHERE Id = " +
        std::to_string(playerTaskId)
    );
}

bool MonsterTaskManager::cancelTask(uint32_t playerId, uint32_t taskId) {
    Database *db = Database::getInstance();

    return db->executeQuery(
        "DELETE FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND TaskId = " + std::to_string(taskId)
    );
}

bool MonsterTaskManager::updateTaskProgress(
    uint32_t playerId,
    uint32_t taskId,
    uint32_t kills
) {
    if (kills == 0) {
        kills = 1;
    }

    Database *db = Database::getInstance();

    DBResult_ptr result = db->storeQuery(
        "SELECT Id, Progress, Amount "
        "FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND TaskId = " + std::to_string(taskId) +
        " AND Finished = 0 "
        "LIMIT 1"
    );

    if (!result) {
        return false;
    }

    uint32_t playerTaskId = result->getNumber<uint32_t>("Id");
    uint32_t currentProgress = result->getNumber<uint32_t>("Progress");
    uint32_t amount = result->getNumber<uint32_t>("Amount");

    uint32_t newProgress = currentProgress + kills;

    if (newProgress >= amount) {
        return db->executeQuery(
            "UPDATE PlayerTasks SET "
            "Progress = " + std::to_string(newProgress) + ", "
            "Finished = 1, "
            "EndTime = NOW() "
            "WHERE Id = " + std::to_string(playerTaskId)
        );
    }

    return db->executeQuery(
        "UPDATE PlayerTasks SET "
        "Progress = " + std::to_string(newProgress) +
        " WHERE Id = " + std::to_string(playerTaskId)
    );
}

ClaimRewardResult MonsterTaskManager::claimReward(
    uint32_t playerId,
    uint32_t playerTaskId,
    RewardType rewardType
) {
    ClaimRewardResult result{};
    Database *db = Database::getInstance();

    DBResult_ptr q = db->storeQuery(
        "SELECT "
        "Id, TaskId, Amount, Finished, "
        "Reward_Gold, Reward_Experience, Reward_TaskPoints "
        "FROM PlayerTasks "
        "WHERE Id = " + std::to_string(playerTaskId) +
        " AND PlayerId = " + std::to_string(playerId) +
        " LIMIT 1"
    );

    if (!q) {
        result.status = ClaimRewardStatus::TaskNotFound;
        return result;
    }

    if (q->getNumber<uint32_t>("Finished") == 0) {
        result.status = ClaimRewardStatus::NotFinished;
        return result;
    }

    const uint32_t taskId = q->getNumber<uint32_t>("TaskId");
    const uint32_t amount = q->getNumber<uint32_t>("Amount");

    const uint64_t rewardGold = q->getNumber<uint64_t>("Reward_Gold");
    const uint64_t rewardExp = q->getNumber<uint64_t>("Reward_Experience");
    const uint32_t taskPoints = q->getNumber<uint32_t>("Reward_TaskPoints");

    uint64_t finalGold = 0;
    uint64_t finalExp = 0;

    switch (rewardType) {
        case RewardType::Gold:
            finalGold = rewardGold;
            break;

        case RewardType::Experience:
            finalExp = rewardExp;
            break;

        case RewardType::Split:
            finalGold = rewardGold / 2;
            finalExp = rewardExp / 2;
            break;

        default:
            result.status = ClaimRewardStatus::InvalidRewardType;
            return result;
    }

    if (!db->executeQuery(
        "INSERT INTO playertaskhistories "
        "(PlayerId, TaskId, RewardType, Gold, Experience, TaskPoints, KillsCompleted, CreatedAt) VALUES ("
        + std::to_string(playerId) + ", "
        + std::to_string(taskId) + ", "
        + std::to_string(static_cast<uint32_t>(rewardType) + 1) + ", "
        + std::to_string(finalGold) + ", "
        + std::to_string(finalExp) + ", "
        + std::to_string(taskPoints) + ", "
        + std::to_string(amount) + ", "
        "NOW())"
    )) {
        result.status = ClaimRewardStatus::DbError;
        return result;
    }

    if (!db->executeQuery(
        "UPDATE Players SET TaskPoints = TaskPoints + " + std::to_string(taskPoints) +
        " WHERE id = " + std::to_string(playerId)
    )) {
        result.status = ClaimRewardStatus::DbError;
        return result;
    }

    if (!db->executeQuery(
        "DELETE FROM PlayerTasks WHERE Id = " + std::to_string(playerTaskId)
    )) {
        result.status = ClaimRewardStatus::DbError;
        return result;
    }

    result.status = ClaimRewardStatus::Success;
    result.gold = finalGold;
    result.experience = finalExp;
    result.taskPoints = taskPoints;
    result.taskId = taskId;
    result.amount = amount;

    return result;
}


PlayerMonsterTask MonsterTaskManager::getActiveTask(uint32_t playerId) {
    PlayerMonsterTask task{};

    DBResult_ptr result = Database::getInstance()->storeQuery(
        "SELECT "
        "Id, PlayerId, TaskId, Amount, Progress, Paused, Finished, Active, "
        "StartTime, EndTime, "
        "Reward_Gold, Reward_Experience, Reward_TaskPoints "
        "FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND Active = 1"
        " AND Finished = 0"
        " AND Paused = 0"
        " LIMIT 1"
    );

    if (!result) {
        return task;
    }

    task.id = result->getNumber<uint32_t>("Id");
    task.playerId = result->getNumber<uint32_t>("PlayerId");
    task.taskId = result->getNumber<uint32_t>("TaskId");

    task.amount = result->getNumber<uint32_t>("Amount");
    task.progress = result->getNumber<uint32_t>("Progress");

    task.paused = result->getNumber<uint32_t>("Paused") != 0;
    task.finished = result->getNumber<uint32_t>("Finished") != 0;
    task.active = result->getNumber<uint32_t>("Active") != 0;

    task.startTime = result->getNumber<std::time_t>("StartTime");

    if (result->getString("EndTime").empty()) {
        task.endTime = 0;
    } else {
        task.endTime = result->getNumber<std::time_t>("EndTime");
    }

    task.rewardGold = result->getNumber<uint64_t>("Reward_Gold");
    task.rewardExperience = result->getNumber<uint64_t>("Reward_Experience");
    task.rewardTaskPoints = result->getNumber<uint32_t>("Reward_TaskPoints");

    return task;
}


const std::vector<MonsterTaskDefinition> &MonsterTaskManager::getMonsterTaskDefinitionList() const {
    return monsterTaskDefinitionList;
}

std::vector<PlayerMonsterTask> MonsterTaskManager::getPlayerMonsterTasks(uint32_t playerId) {
    std::vector<PlayerMonsterTask> tasks;

    DBResult_ptr result = Database::getInstance()->storeQuery(
        "SELECT "
        "Id, PlayerId, TaskId, Amount, Progress, Paused, Finished, Active, "
        "StartTime, EndTime, "
        "Reward_Gold, Reward_Experience, Reward_TaskPoints "
        "FROM PlayerTasks "
        "WHERE PlayerId = " + std::to_string(playerId) +
        " AND Active = 1"
    );


    if (!result) {
        return tasks;
    }

    do {
        PlayerMonsterTask task;

        task.id = result->getNumber<uint32_t>("Id");
        task.playerId = result->getNumber<uint32_t>("PlayerId");
        task.taskId = result->getNumber<uint32_t>("TaskId");

        task.amount = result->getNumber<uint32_t>("Amount");
        task.progress = result->getNumber<uint32_t>("Progress");

        task.paused = result->getNumber<uint32_t>("Paused") != 0;
        task.finished = result->getNumber<uint32_t>("Finished") != 0;
        task.active = result->getNumber<uint32_t>("Active") != 0;


        task.startTime = result->getNumber<std::time_t>("StartTime");

        if (result->getString("EndTime").empty()) {
            task.endTime = 0;
        } else {
            task.endTime = result->getNumber<std::time_t>("EndTime");
        }

        task.rewardGold = result->getNumber<uint64_t>("Reward_Gold");
        task.rewardExperience = result->getNumber<uint64_t>("Reward_Experience");
        task.rewardTaskPoints = result->getNumber<uint32_t>("Reward_TaskPoints");

        tasks.push_back(task);
    } while (result->next());

    return tasks;
}


MonsterTaskDefinition MonsterTaskManager::getTaskDefinitionById(uint32_t taskId) {
    for (const MonsterTaskDefinition &def: monsterTaskDefinitionList) {
        if (def.id == taskId) {
            return def;
        }
    }

    return MonsterTaskDefinition{};
}

PlayerMonsterTask MonsterTaskManager::getPlayerTaskById(uint32_t playerId, uint32_t taskId) {
    const auto tasks = getPlayerMonsterTasks(playerId);

    for (const PlayerMonsterTask &task: tasks) {
        if (task.id == taskId) {
            return task;
        }
    }

    return PlayerMonsterTask{};
}

uint32_t MonsterTaskManager::calculateGoldReward(
    uint32_t experience,
    uint32_t amount,
    TaskCategory category
) {
    if (amount > 1000) {
        amount = 1000;
    }

    double baseRewardPerKill = static_cast<double>(experience) / 5.0;

    if (category >= TaskCategory::High) {
        baseRewardPerKill /= 3.0;
    }

    uint32_t totalGold = static_cast<uint32_t>(
        std::floor(baseRewardPerKill * static_cast<double>(amount))
    );

    return totalGold;
}

uint64_t MonsterTaskManager::calculateExperienceReward(
    uint32_t amount,
    uint32_t experience
) {
    if (amount > 1000) {
        amount = 1000;
    }

    double totalExp = static_cast<double>(amount)
                      * static_cast<double>(experience)
                      * 0.55;

    return static_cast<uint64_t>(std::floor(totalExp));
}

uint32_t MonsterTaskManager::calculateTaskPointsReward(
    uint32_t amount,
    uint32_t experience,
    TaskCategory category
) {
    if (amount > 1000) {
        amount = 1000;
    }

    double categoryMultiplier = 1.0;

    switch (category) {
        case TaskCategory::Low:
            categoryMultiplier = 0.1;
            break;
        case TaskCategory::Medium:
            categoryMultiplier = 0.5;
            break;
        case TaskCategory::High:
            categoryMultiplier = 1.0;
            break;
        case TaskCategory::VeryHigh:
            categoryMultiplier = 1.5;
            break;
        default:
            categoryMultiplier = 1.0;
            break;
    }

    double basePointsPerKill =
            (static_cast<double>(experience) / 10000.0) * categoryMultiplier;

    double totalTP = std::floor(basePointsPerKill * static_cast<double>(amount));

    totalTP = std::floor(totalTP / 2.0);

    return static_cast<uint32_t>(totalTP);
}
