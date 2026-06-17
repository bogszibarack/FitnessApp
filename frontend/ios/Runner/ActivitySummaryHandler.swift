import Flutter
import HealthKit

class ActivitySummaryHandler: NSObject {
  private let healthStore = HKHealthStore()
  private let channelName = "com.fitnessapp/activity_summary"

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "requestAuthorization":
        self.requestAuthorization(result: result)
      case "fetchTodaySummary":
        self.fetchTodaySummary(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestAuthorization(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "UNAVAILABLE", message: "HealthKit nem elerheto", details: nil))
      return
    }

    let typesToRead: Set<HKObjectType> = [HKObjectType.activitySummaryType()]
    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
      if let error {
        result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
        return
      }
      result(success)
    }
  }

  private func fetchTodaySummary(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(nil)
      return
    }

    let calendar = Calendar.current
    var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
    dateComponents.calendar = calendar

    let predicate = HKQuery.predicateForActivitySummary(with: dateComponents)
    let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
      if let error {
        result(FlutterError(code: "QUERY_ERROR", message: error.localizedDescription, details: nil))
        return
      }

      guard let summary = summaries?.first else {
        result(nil)
        return
      }

      let moveKcal = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
      let moveGoalKcal = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
      let exerciseMinutes = summary.appleExerciseTime.doubleValue(for: .minute())
      let exerciseGoalMinutes = summary.appleExerciseTimeGoal.doubleValue(for: .minute())
      let standHours = summary.appleStandHours.doubleValue(for: .count())
      let standGoalHours = summary.appleStandHoursGoal.doubleValue(for: .count())

      result([
        "moveKcal": moveKcal,
        "moveGoalKcal": moveGoalKcal,
        "exerciseMinutes": exerciseMinutes,
        "exerciseGoalMinutes": exerciseGoalMinutes,
        "standHours": standHours,
        "standGoalHours": standGoalHours,
      ])
    }

    healthStore.execute(query)
  }
}
