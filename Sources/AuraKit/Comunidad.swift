import Foundation

/// A Spanish autonomous community, with both the code AEMET's OpenData API uses (e.g. "mad")
/// and the area id its website's internal forecast API uses (`webZoom`/`webID`).
///
/// Aura reads the community narrative from the internal API (`AEMETBulletinClient`): it is the
/// only source that stays current for every region. OpenData's text products are unevenly
/// maintained — the per-province files are frozen for several provinces (A Coruña sits at 2022)
/// and the CCAA files can lag weeks to months (Galicia was ~2 months stale). The mapping below
/// was harvested from aemet.es (`prediccion/espana?k=<code>`, hidden `initZoom`/`initLocation`);
/// re-harvest there if AEMET ever renumbers its areas.
public struct Comunidad: Sendable, Hashable {
    /// AEMET OpenData area code, e.g. "mad".
    public let code: String
    /// Display name, e.g. "Comunidad de Madrid".
    public let nombre: String
    /// Zoom segment of the internal API path (`.../PB/{webZoom}/{webID}`).
    public let webZoom: Int
    /// Area id in the internal API path.
    public let webID: Int

    public init(code: String, nombre: String, webZoom: Int, webID: Int) {
        self.code = code
        self.nombre = nombre
        self.webZoom = webZoom
        self.webID = webID
    }

    /// All 17 communities plus Ceuta and Melilla, keyed by AEMET code.
    private static let byCode: [String: Comunidad] = [
        "and": Comunidad(code: "and", nombre: "Andalucía", webZoom: 7, webID: 61),
        "arn": Comunidad(code: "arn", nombre: "Aragón", webZoom: 7, webID: 62),
        "ast": Comunidad(code: "ast", nombre: "Principado de Asturias", webZoom: 8, webID: 6333),
        "bal": Comunidad(code: "bal", nombre: "Illes Balears", webZoom: 7, webID: 64),
        "can": Comunidad(code: "can", nombre: "Cantabria", webZoom: 9, webID: 6639),
        "cat": Comunidad(code: "cat", nombre: "Cataluña", webZoom: 7, webID: 69),
        "ceu": Comunidad(code: "ceu", nombre: "Ciudad de Ceuta", webZoom: 10, webID: 7851),
        "cle": Comunidad(code: "cle", nombre: "Castilla y León", webZoom: 7, webID: 67),
        "clm": Comunidad(code: "clm", nombre: "Castilla-La Mancha", webZoom: 7, webID: 68),
        "coo": Comunidad(code: "coo", nombre: "Canarias", webZoom: 7, webID: 65),
        "ext": Comunidad(code: "ext", nombre: "Extremadura", webZoom: 7, webID: 70),
        "gal": Comunidad(code: "gal", nombre: "Galicia", webZoom: 7, webID: 71),
        "mad": Comunidad(code: "mad", nombre: "Comunidad de Madrid", webZoom: 8, webID: 7228),
        "mel": Comunidad(code: "mel", nombre: "Ciudad de Melilla", webZoom: 10, webID: 7952),
        "mur": Comunidad(code: "mur", nombre: "Región de Murcia", webZoom: 8, webID: 7330),
        "nav": Comunidad(code: "nav", nombre: "Comunidad Foral de Navarra", webZoom: 8, webID: 7431),
        "pva": Comunidad(code: "pva", nombre: "País Vasco", webZoom: 7, webID: 75),
        "rio": Comunidad(code: "rio", nombre: "La Rioja", webZoom: 9, webID: 7626),
        "val": Comunidad(code: "val", nombre: "Comunitat Valenciana", webZoom: 7, webID: 77),
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
