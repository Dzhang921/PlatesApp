import Foundation

/// Offline currency conversion backed by the bundled `currency_rates.json`
/// (USD-based reference rates). All math is done in `Decimal` and results are
/// rounded to 2 decimal places. Unknown codes convert as identity.
enum CurrencyConverter {

    // MARK: - Home currency

    private static let homeCurrencyKey = "homeCurrency"

    /// The user's home currency code. Persisted in UserDefaults under
    /// "homeCurrency"; defaults to the device locale's currency when it exists
    /// in the rates table, else "USD".
    static var homeCurrency: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: homeCurrencyKey),
               !stored.isEmpty {
                return stored.uppercased()
            }
            if let localeCode = Locale.current.currency?.identifier.uppercased(),
               rates[localeCode] != nil {
                return localeCode
            }
            return "USD"
        }
        set {
            UserDefaults.standard.set(newValue.uppercased(), forKey: homeCurrencyKey)
        }
    }

    // MARK: - Conversion

    /// Converts `amount` from `code` into the home currency:
    /// `amount / rate[from] * rate[home]` (rates are units-per-USD).
    /// Identity when either code is missing from the rates table.
    static func toHome(_ amount: Decimal, from code: String) -> Decimal {
        let from = code.uppercased()
        let home = homeCurrency
        guard from != home,
              let fromRate = rates[from], fromRate > 0,
              let homeRate = rates[home], homeRate > 0 else {
            return amount
        }
        return rounded(amount / fromRate * homeRate, scale: 2)
    }

    /// A short display symbol for a currency code ("$", "€", "HK$", …).
    /// Falls back to the code itself for unmapped currencies.
    static func symbol(for code: String) -> String {
        let key = code.uppercased()
        return symbols[key] ?? key
    }

    /// Every code in the rates file, with the home currency and the major
    /// currencies (USD, EUR, GBP, JPY) first, then the rest alphabetically.
    static var supportedCurrencies: [String] {
        let keys = Set(rates.keys)
        var front: [String] = []
        for code in [homeCurrency, "USD", "EUR", "GBP", "JPY"]
        where keys.contains(code) && !front.contains(code) {
            front.append(code)
        }
        return front + keys.subtracting(front).sorted()
    }

    // MARK: - Rates (loaded lazily, once)

    private struct RatesFile: Decodable {
        var base: String
        var rates: [String: Double]
    }

    /// Units of each currency per 1 USD, decoded once from the bundle.
    /// Values pass through `Decimal(string:)` so 0.92 stays exactly 0.92.
    private static let rates: [String: Decimal] = {
        guard let url = Bundle.main.url(forResource: "currency_rates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(RatesFile.self, from: data) else {
            return ["USD": 1]
        }
        let posix = Locale(identifier: "en_US_POSIX")
        var table: [String: Decimal] = [:]
        table.reserveCapacity(file.rates.count)
        for (code, value) in file.rates where value > 0 {
            table[code.uppercased()] = Decimal(string: "\(value)", locale: posix) ?? Decimal(value)
        }
        return table.isEmpty ? ["USD": 1] : table
    }()

    // MARK: - Helpers

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    private static let symbols: [String: String] = [
        "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "CNY": "CN¥",
        "KRW": "₩", "THB": "฿", "VND": "₫", "INR": "₹",
        "SEK": "kr", "NOK": "kr", "DKK": "kr", "ISK": "kr",
        "CHF": "CHF ", "HKD": "HK$", "SGD": "S$", "TWD": "NT$",
        "CAD": "C$", "AUD": "A$", "NZD": "NZ$", "BRL": "R$",
        "MXN": "MX$", "ARS": "AR$", "CLP": "CL$", "PEN": "S/",
        "PLN": "zł", "CZK": "Kč", "HUF": "Ft", "RON": "lei ",
        "TRY": "₺", "AED": "AED ", "SAR": "SAR ", "QAR": "QAR ",
        "ILS": "₪", "ZAR": "R", "EGP": "E£", "MAD": "MAD ",
        "PHP": "₱", "IDR": "Rp", "MYR": "RM", "MOP": "MOP$"
    ]
}
