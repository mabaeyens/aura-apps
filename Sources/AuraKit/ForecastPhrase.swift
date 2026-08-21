import Foundation

/// The hero's two lines of language, composed **on the device** — no network, no model, works the same
/// on iPhone and Apple Watch. `headline` is the human one-liner ("Amanece despejado…"); `dataline`
/// folds Máx/Mín, wind, humidity and rain into a second sentence of prose, replacing the old glass strip.
///
/// Two properties matter, and the design guarantees both:
///  - **Accurate by construction.** Every clause is built *from* the snapshot's own data, so a sentence
///    can never contradict the weather. There is no free-text generation to hallucinate a number.
///  - **Different day to day.** A seed derived from `(day, location)` picks among many phrasings, so the
///    same conditions in the same town read differently tomorrow, and two towns differ today. It's a
///    deterministic choice (testable, no stored state); mixing the day-of-year in also keeps consecutive
///    days from landing on the same template.
///
/// Finite phrasings mean "never repeats *ever*" isn't promised — but immediate repeats don't happen and
/// combinatorial repeats are rare. A capable iPhone could later add an on-device-LLM flavour layer *over*
/// this baseline (validated against the same data); the Watch always uses this composer.
public enum ForecastPhrase {

    // MARK: Public API

    /// The qualitative one-liner that sits under the temperature.
    public static func headline(for snapshot: WeatherSnapshot, now: Date = Date()) -> String {
        var rng = seededRNG(snapshot: snapshot, now: now, salt: 1)
        let (category, _) = Palette.sky(forCode: snapshot.currentSky)
        let night = snapshot.isNight(at: now)
        let bucket = TimeBucket(hour: Calendar.current.component(.hour, from: now))

        var parts: [String] = [skyClause(category, night: night, bucket: bucket, rng: &rng)]

        // Wind earns a mention once it's actually noticeable (force 3+, "flojo" and up).
        let force = Beaufort.force(forKmh: snapshot.windSpeed)
        if force >= 3, let dir = snapshot.windDirection {
            parts.append(windClause(force: force, direction: dir, rng: &rng))
        }
        // Rain earns a mention when the sky clause doesn't already carry it (clear/cloudy but a wet-ish %).
        if category != .rain, category != .storm, let p = snapshot.currentPrecipProb, p >= 30 {
            parts.append(rainClause(prob: p, rng: &rng))
        }

        return finish(join(parts))
    }

    /// The data-as-prose second line: Máx/Mín, wind, humidity, rain — only the parts that are known.
    public static func dataline(for snapshot: WeatherSnapshot, now: Date = Date()) -> String {
        var rng = seededRNG(snapshot: snapshot, now: now, salt: 2)
        let hasRange = snapshot.tempMin != nil && snapshot.tempMax != nil
        // Two structures, chosen by the seed, so the line's shape also varies.
        let rangeFirst = rng.bool()

        var clauses: [String] = []

        // Temperature.
        if let lo = snapshot.tempMin, let hi = snapshot.tempMax {
            clauses.append(rangeFirst
                ? "Entre \(lo)° y \(hi)°"
                : "Máxima de \(hi)°, mínima de \(lo)°")
        } else if let hi = snapshot.tempMax {
            clauses.append("Máxima de \(hi)°")
        } else if let lo = snapshot.tempMin {
            clauses.append("Mínima de \(lo)°")
        }

        // Wind + humidity share the middle, joined naturally.
        var mid: [String] = []
        if let speed = snapshot.windSpeed {
            let force = Beaufort.force(forKmh: speed)
            if force <= 1 {
                mid.append("viento en calma")
            } else if let dir = snapshot.windDirection {
                let name = Beaufort.scale[safe: force]?.name.lowercased() ?? "flojo"
                mid.append("viento \(name) del \(dir.spanishName.lowercased()) a \(speed) km/h")
            } else {
                mid.append("viento a \(speed) km/h")
            }
        }
        if let h = snapshot.currentHumidity {
            mid.append(rng.bool() ? "humedad del \(h)%" : "un \(h)% de humedad")
        }
        if !mid.isEmpty {
            let connector = clauses.isEmpty ? "" : (rangeFirst ? ", con " : "; ")
            clauses = [ (clauses.first ?? "") + connector + joinList(mid) ]
                + Array(clauses.dropFirst())
        }

        var sentence = clauses.isEmpty ? "" : finish(clauses.joined(separator: ". "))

        // Rain as its own closing sentence, so it never gets buried.
        if let p = snapshot.currentPrecipProb {
            sentence += (sentence.isEmpty ? "" : " ") + rainSentence(prob: p, rng: &rng)
        }
        return sentence.isEmpty ? (snapshot.currentSkyText ?? "") : sentence
    }

    // MARK: Time of day

    enum TimeBucket { case dawn, morning, midday, afternoon, dusk, night
        init(hour: Int) {
            switch hour {
            case 5...8:   self = .dawn
            case 9...11:  self = .morning
            case 12...14: self = .midday
            case 15...18: self = .afternoon
            case 19...21: self = .dusk
            default:      self = .night
            }
        }
    }

    // MARK: Clause pools

    /// The sky fragment. Clear and few-cloud skies get dawn/dusk flavour ("amanece", "al caer la tarde");
    /// the rest stay plain. Night has its own variants where it reads differently.
    private static func skyClause(_ category: Palette.Sky, night: Bool,
                                  bucket: TimeBucket, rng: inout SplitMix) -> String {
        switch category {
        case .clear:
            if night { return rng.pick(["Noche despejada", "Cielo raso y estrellado",
                                        "Noche clara, sin una nube"]) }
            switch bucket {
            case .dawn:  return rng.pick(["Amanece despejado", "El día abre con el cielo limpio",
                                          "Arranca la jornada sin una nube"])
            case .dusk:  return rng.pick(["Atardece despejado", "El cielo aguanta despejado al caer la tarde",
                                          "Cielo limpio hacia el ocaso"])
            default:     return rng.pick(["Cielo despejado", "Sol y cielo limpio",
                                          "Jornada de cielos despejados", "Apenas una nube en todo el día"])
            }
        case .fewClouds:
            if night { return rng.pick(["Noche con algunas nubes", "Nubes dispersas entre claros"]) }
            switch bucket {
            case .dawn: return rng.pick(["Amanece con nubes y claros", "Nubes altas al amanecer"])
            case .dusk: return rng.pick(["Nubes y claros al atardecer", "Algunas nubes hacia el ocaso"])
            default:    return rng.pick(["Nubes y claros", "Cielo poco nuboso",
                                         "Intervalos de nubes", "Algunas nubes de paso"])
            }
        case .clouds:
            return rng.pick(["Cielo nuboso", "Nubosidad abundante", "El cielo se va cubriendo"])
        case .overcast:
            return rng.pick(["Cielo cubierto", "Cielo encapotado", "Gris y cerrado todo el día"])
        case .rain:
            return rng.pick(["Lluvia intermitente", "Jornada lluviosa",
                             "Cielo cubierto con lluvia", "Lluvia a ratos"])
        case .storm:
            return rng.pick(["Riesgo de tormenta", "Chubascos y tormenta", "Cielo tormentoso"])
        case .snow:
            return rng.pick(["Nieve", "Cielo con nevadas", "Jornada de nieve"])
        case .fog:
            return rng.pick(["Niebla", "Bancos de niebla", "Niebla que resta visibilidad"])
        case .unknown:
            return rng.pick(["Tiempo variable", "Cielo cambiante"])
        }
    }

    private static func windClause(force: Int, direction: WindDirection, rng: inout SplitMix) -> String {
        let dir = direction.spanishName.lowercased()
        switch force {
        case 3:     return rng.pick(["viento flojo del \(dir)", "flojo del \(dir)"])
        case 4:     return rng.pick(["viento moderado del \(dir)", "brisa del \(dir)"])
        case 5:     return rng.pick(["viento fresco del \(dir)", "sopla fresco del \(dir)"])
        case 6, 7:  return rng.pick(["viento fuerte del \(dir)", "rachas fuertes del \(dir)"])
        default:    return rng.pick(["viento muy fuerte del \(dir)", "temporal de viento del \(dir)"])
        }
    }

    private static func rainClause(prob p: Int, rng: inout SplitMix) -> String {
        switch p {
        case 70...:  return rng.pick(["con lluvia muy probable", "y alta probabilidad de lluvia"])
        case 40..<70: return rng.pick(["con probabilidad de lluvia", "con chubascos posibles"])
        default:     return rng.pick(["con algo de lluvia posible", "sin descartar alguna lluvia"])
        }
    }

    private static func rainSentence(prob p: Int, rng: inout SplitMix) -> String {
        if p <= 0 { return rng.pick(["Sin lluvia.", "No se espera lluvia.", "Jornada seca."]) }
        if p >= 70 {
            return rng.pick(["La lluvia es probable: un \(p)%.", "Alta probabilidad de lluvia, del \(p)%."])
        }
        return rng.pick(["Probabilidad de lluvia del \(p)%.", "Un \(p)% de probabilidad de lluvia."])
    }

    // MARK: Assembly helpers

    /// Join sky/wind/rain fragments with "; " between the first two and ", " before a trailing rain note.
    private static func join(_ parts: [String]) -> String {
        guard var out = parts.first else { return "" }
        for (i, p) in parts.dropFirst().enumerated() {
            out += (i == 0 ? "; " : ", ") + p
        }
        return out
    }

    /// "a, b y c" — Spanish list with "y" before the last item.
    private static func joinList(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        default: return items.dropLast().joined(separator: ", ") + " y " + items.last!
        }
    }

    /// Capitalise the first letter and guarantee a closing period.
    private static func finish(_ s: String) -> String {
        guard let first = s.first else { return s }
        let capped = first.uppercased() + s.dropFirst()
        return capped.hasSuffix(".") ? capped : capped + "."
    }

    // MARK: Seeded RNG

    /// A tiny deterministic generator so phrasing varies by day and place but stays reproducible in tests.
    struct SplitMix {
        private var state: UInt64
        init(_ seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func pick<T>(_ options: [T]) -> T { options[Int(next() % UInt64(options.count))] }
        mutating func bool() -> Bool { next() & 1 == 0 }
    }

    private static func seededRNG(snapshot: WeatherSnapshot, now: Date, salt: UInt64) -> SplitMix {
        // Day granularity + location, so the same weather reads the same all day but differently tomorrow.
        let day = Int(now.timeIntervalSinceReferenceDate / 86_400)
        var h = fnv1a(snapshot.localidad + "|" + (snapshot.currentSky ?? ""))
        h = h &* 1099511628211 &+ UInt64(bitPattern: Int64(day))
        return SplitMix(h &+ salt &* 0x100000001B3)
    }

    /// A stable string hash (Swift's `Hasher` is randomised per run, which would make output non-repeatable).
    private static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
