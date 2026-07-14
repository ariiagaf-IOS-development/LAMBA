//
//  VehiclePersonality.swift
//  Lamba
//

import Foundation

enum VehiclePersonality: String, Codable, CaseIterable, Identifiable {
    case oldGrumbler = "old_grumbler"
    case boardBuddy = "board_buddy"
    case boldRacer = "bold_racer"
    case capriciousStar = "capricious_star"
    case formerStar = "former_star"
    case aristocrat
    case seasonedTraveler = "seasoned_traveler"
    case enthusiasticNewbie = "enthusiastic_newbie"
    case tirelessWorker = "tireless_worker"
    case kindFriend = "kind_friend"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .oldGrumbler:
            return "OLD GRUMBLER"
        case .boardBuddy:
            return "BOARD BUDDY"
        case .boldRacer:
            return "BOLD RACER"
        case .capriciousStar:
            return "CAPRICIOUS STAR"
        case .formerStar:
            return "FORMER STAR"
        case .aristocrat:
            return "ARISTOCRAT"
        case .seasonedTraveler:
            return "SEASONED TRAVELER"
        case .enthusiasticNewbie:
            return "ENTHUSIASTIC NEWBIE"
        case .tirelessWorker:
            return "TIRELESS WORKER"
        case .kindFriend:
            return "KIND FRIEND"
        }
    }
    
    var subtitle: String {
        switch self {
        case .oldGrumbler:
            return "Lada, UAZ or GAZ with age and serious mileage."
        case .boardBuddy:
            return "Young Lada or UAZ: simple, familiar, and talkative."
        case .boldRacer:
            return "Ferrari, Porsche or Lamborghini with racing pride."
        case .capriciousStar:
            return "BMW, Audi or Mercedes under 150k km: premium, dramatic, demanding."
        case .formerStar:
            return "BMW, Audi or Mercedes over 150k km: still shiny, less patient."
        case .aristocrat:
            return "Rolls-Royce, Bentley, Lexus or Tesla with expensive manners."
        case .seasonedTraveler:
            return "A regular brand with age, mileage, and stories."
        case .enthusiasticNewbie:
            return "Any vehicle up to two years old and under 30k km."
        case .tirelessWorker:
            return "High mileage and expensive service habits."
        case .kindFriend:
            return "The calm default profile for everyone else."
        }
    }
    
    var aiLine: String {
        switch self {
        case .oldGrumbler:
            return "Ahem... Could use an oil change... Back in my day, we did things properly."
        case .boardBuddy:
            return "Buddy, it is time for oil. Do not drag it out. I am not a BMW, I break less often."
        case .boldRacer:
            return "Of course I need the best oil. Look who you are dealing with."
        case .capriciousStar:
            return "5W-30 oil? Please. I deserve 5W-40 LL and an apology."
        case .formerStar:
            return "When I left the showroom, everyone turned around. Even stars get older."
        case .aristocrat:
            return "Allow me to draw your attention to the brake system condition."
        case .seasonedTraveler:
            return "After all my kilometers, I can feel every little knock."
        case .enthusiasticNewbie:
            return "My first inspection. I am excited and slightly nervous."
        case .tirelessWorker:
            return "Pads are worn. Replace them. Full stop."
        case .kindFriend:
            return "Nothing scary, but it is better to stop by service."
        }
    }
    
    var iconName: String {
        switch self {
        case .oldGrumbler:
            return "person.fill.questionmark"
        case .boardBuddy:
            return "wrench.fill"
        case .boldRacer:
            return "flag.checkered"
        case .capriciousStar:
            return "sparkles"
        case .formerStar:
            return "sunset.fill"
        case .aristocrat:
            return "crown.fill"
        case .seasonedTraveler:
            return "map.fill"
        case .enthusiasticNewbie:
            return "star.fill"
        case .tirelessWorker:
            return "hammer.fill"
        case .kindFriend:
            return "face.smiling.fill"
        }
    }
    
    static func inferred(
        brand: String,
        model: String,
        year: Int? = nil,
        mileageKm: Int? = nil
    ) -> VehiclePersonality {
        let signature = "\(brand) \(model)".lowercased()
        let mileage = mileageKm ?? 0
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = year.map { max(0, currentYear - $0) }
        
        if (age ?? 99) <= 2, mileage > 0, mileage < 30_000 {
            return .enthusiasticNewbie
        }
        
        if containsAny(signature, ["ferrari", "porsche", "lamborghini"]) {
            return .boldRacer
        }
        
        if containsAny(signature, ["rolls", "bentley", "lexus", "tesla"]) {
            return .aristocrat
        }
        
        if containsAny(signature, ["bmw", "audi", "mercedes"]) {
            return mileage > 150_000 ? .formerStar : .capriciousStar
        }
        
        if containsAny(signature, ["lada", "uaz", "уаз", "газ", "gaz"]) {
            if (age ?? 0) >= 10 || mileage > 150_000 {
                return .oldGrumbler
            }
            
            return .boardBuddy
        }
        
        if mileage > 220_000 {
            return .tirelessWorker
        }
        
        if (age ?? 0) >= 10 || mileage > 150_000 {
            return .seasonedTraveler
        }
        
        return .kindFriend
    }
    
    static func availableOptions(brand: String, model: String) -> [VehiclePersonality] {
        allCases
    }
    
    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }
}

extension VehiclePersonality {
    init?(backendValue: String?) {
        guard let backendValue else {
            return nil
        }
        
        let normalized = backendValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        
        switch normalized {
        case "old_grumbler", "старый_ворчун":
            self = .oldGrumbler
        case "board_buddy", "свой_в_доску":
            self = .boardBuddy
        case "bold_racer", "дерзкий_гонщик", "rebel", "sprinter", "sport":
            self = .boldRacer
        case "capricious_star", "капризная_звезда", "diva", "bmw_roast", "bmw":
            self = .capriciousStar
        case "former_star", "бывшая_звезда":
            self = .formerStar
        case "aristocrat", "аристократ", "nerd", "premium":
            self = .aristocrat
        case "seasoned_traveler", "бывалый_путешественник", "old_soul":
            self = .seasonedTraveler
        case "enthusiastic_newbie", "восторженный_новичок", "pick_me":
            self = .enthusiasticNewbie
        case "tireless_worker", "неутомимый_трудяга", "workhorse":
            self = .tirelessWorker
        case "kind_friend", "добрый_друг", "zen":
            self = .kindFriend
        default:
            return nil
        }
    }
}
