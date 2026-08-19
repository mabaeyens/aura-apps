import Foundation

/// A Spanish autonomous community, carrying the code AEMET's OpenData API uses (e.g. "mad").
///
/// Aura reads the community narrative from OpenData's normalized-text products, keyed by this
/// `code` (see `AEMETClient.comunidadBulletin`). The `hoy` product is amendment-only, so the
/// fetch resolves "today" from the daily `manana` archive — see that method for the details.
public struct Comunidad: Sendable, Hashable {
    /// AEMET OpenData area code, e.g. "mad".
    public let code: String
    /// Display name, e.g. "Comunidad de Madrid".
    public let nombre: String

    public init(code: String, nombre: String) {
        self.code = code
        self.nombre = nombre
    }

    /// All 17 communities plus Ceuta and Melilla, keyed by AEMET code.
    private static let byCode: [String: Comunidad] = [
        "and": Comunidad(code: "and", nombre: "Andalucía"),
        "arn": Comunidad(code: "arn", nombre: "Aragón"),
        "ast": Comunidad(code: "ast", nombre: "Principado de Asturias"),
        "bal": Comunidad(code: "bal", nombre: "Illes Balears"),
        "can": Comunidad(code: "can", nombre: "Cantabria"),
        "cat": Comunidad(code: "cat", nombre: "Cataluña"),
        "ceu": Comunidad(code: "ceu", nombre: "Ciudad de Ceuta"),
        "cle": Comunidad(code: "cle", nombre: "Castilla y León"),
        "clm": Comunidad(code: "clm", nombre: "Castilla-La Mancha"),
        "coo": Comunidad(code: "coo", nombre: "Canarias"),
        "ext": Comunidad(code: "ext", nombre: "Extremadura"),
        "gal": Comunidad(code: "gal", nombre: "Galicia"),
        "mad": Comunidad(code: "mad", nombre: "Comunidad de Madrid"),
        "mel": Comunidad(code: "mel", nombre: "Ciudad de Melilla"),
        "mur": Comunidad(code: "mur", nombre: "Región de Murcia"),
        "nav": Comunidad(code: "nav", nombre: "Comunidad Foral de Navarra"),
        "pva": Comunidad(code: "pva", nombre: "País Vasco"),
        "rio": Comunidad(code: "rio", nombre: "La Rioja"),
        "val": Comunidad(code: "val", nombre: "Comunitat Valenciana"),
    ]

    /// 2-digit INE province code → AEMET CCAA code, for all 52 provinces.
    private static let provinceToCCAA: [String: String] = [
        "01": "pva", "02": "clm", "03": "val", "04": "and", "05": "cle", "06": "ext",
        "07": "bal", "08": "cat", "09": "cle", "10": "ext", "11": "and", "12": "val",
        "13": "clm", "14": "and", "15": "gal", "16": "clm", "17": "cat", "18": "and",
        "19": "clm", "20": "pva", "21": "and", "22": "arn", "23": "and", "24": "cle",
        "25": "cat", "26": "rio", "27": "gal", "28": "mad", "29": "and", "30": "mur",
        "31": "nav", "32": "gal", "33": "ast", "34": "cle", "35": "coo", "36": "gal",
        "37": "cle", "38": "coo", "39": "can", "40": "cle", "41": "and", "42": "cle",
        "43": "cat", "44": "arn", "45": "clm", "46": "val", "47": "cle", "48": "pva",
        "49": "cle", "50": "arn", "51": "ceu", "52": "mel",
    ]

    /// The community a 2-digit INE province code belongs to, if known.
    public static func forProvincia(_ provinciaCode: String) -> Comunidad? {
        guard let code = provinceToCCAA[provinciaCode] else { return nil }
        return byCode[code]
    }
}

public extension Location {
    /// The autonomous community this municipality belongs to.
    var comunidad: Comunidad? { Comunidad.forProvincia(provinciaCode) }
}
