import Foundation

class RateCoinMapper {
    private let disabledCoins = ["EOSDT", "PGL", "PPT", "SAI", "WBTC", "WETH", "SWAP"]
    private let convertedCoins = [
        "HOT": "HOLO",
    ]
}

extension RateCoinMapper: IRateCoinMapper {

    func convert(coin: Coin) -> Coin? {
        guard !disabledCoins.contains(coin.code) else {
            return nil
        }

        if let convertedCoiCode = convertedCoins[coin.code] {
            return Coin(id: coin.id, title: coin.title, code: convertedCoiCode, decimal: coin.decimal, type: coin.type)
        } else {
            return coin
        }
    }

    func convert(coinCode: String) -> String? {
        guard !disabledCoins.contains(coinCode) else {
            return nil
        }

        return convertedCoins[coinCode] ?? coinCode
    }

    func unconvert(coinCode: String) -> [String] {
        var coinCodes = [coinCode]

        for (from, to) in convertedCoins {
            if to == coinCode {
                coinCodes.append(from)
            }
        }

        return coinCodes
    }

}
