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
            return "СТАРЫЙ ВОРЧУН"
        case .boardBuddy:
            return "СВОЙ В ДОСКУ"
        case .boldRacer:
            return "ДЕРЗКИЙ ГОНЩИК"
        case .capriciousStar:
            return "КАПРИЗНАЯ ЗВЕЗДА"
        case .formerStar:
            return "БЫВШАЯ ЗВЕЗДА"
        case .aristocrat:
            return "АРИСТОКРАТ"
        case .seasonedTraveler:
            return "БЫВАЛЫЙ ПУТЕШЕСТВЕННИК"
        case .enthusiasticNewbie:
            return "ВОСТОРЖЕННЫЙ НОВИЧОК"
        case .tirelessWorker:
            return "НЕУТОМИМЫЙ ТРУДЯГА"
        case .kindFriend:
            return "ДОБРЫЙ ДРУГ"
        }
    }
    
    var subtitle: String {
        switch self {
        case .oldGrumbler:
            return "Лада, УАЗ или ГАЗ с возрастом и большим пробегом."
        case .boardBuddy:
            return "Молодая Лада или УАЗ, простая и разговорчивая."
        case .boldRacer:
            return "Ferrari, Porsche или Lamborghini с гоночным самолюбием."
        case .capriciousStar:
            return "BMW, Audi или Mercedes до 150k км: премиум, драма, требования."
        case .formerStar:
            return "BMW, Audi или Mercedes после 150k км: блеск остался, терпение нет."
        case .aristocrat:
            return "Rolls-Royce, Bentley, Lexus или Tesla с дорогими манерами."
        case .seasonedTraveler:
            return "Обычная марка, возраст и большой пробег."
        case .enthusiasticNewbie:
            return "Любая машина до двух лет и до 30k км."
        case .tirelessWorker:
            return "Большой пробег и дорогое обслуживание."
        case .kindFriend:
            return "Дефолтный спокойный характер для всех остальных."
        }
    }
    
    var aiLine: String {
        switch self {
        case .oldGrumbler:
            return "Кхе-кхе... Масло бы поменять... В мои годы такого не было..."
        case .boardBuddy:
            return "Братан, масло пора менять, не тяни. Я не BMW, зато ломаюсь реже!"
        case .boldRacer:
            return "Конечно, мне нужно лучшее масло. Ты же видишь, с кем имеешь дело."
        case .capriciousStar:
            return "Масло 5W-30?! Я заслуживаю только 5W-40 LL!"
        case .formerStar:
            return "Когда я выехал из салона, все оборачивались... Даже звёзды стареют."
        case .aristocrat:
            return "Позвольте обратить ваше внимание на состояние тормозной системы."
        case .seasonedTraveler:
            return "За мои километры я научился чувствовать каждый стук."
        case .enthusiasticNewbie:
            return "Мой первый техосмотр! Волнуюсь!"
        case .tirelessWorker:
            return "Колодки стёрлись. Менять. Точка."
        case .kindFriend:
            return "Ничего страшного, но лучше заглянуть на сервис."
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
