import ThemeKit

struct AddBinanceTokenModule {

    static func viewController() -> UIViewController {
        let blockchainService = AddBinanceTokenBlockchainService(
                appConfigProvider: App.shared.appConfigProvider,
                networkManager: App.shared.networkManager
        )
        let service = AddTokenService(blockchainService: blockchainService, coinManager: App.shared.coinManager)
        let viewModel = AddTokenViewModel(service: service)

        let viewController = AddTokenViewController(
                viewModel: viewModel,
                pageTitle: "add_bep2_token.title".localized,
                referenceTitle: "add_bep2_token.token_symbol".localized
        )

        return ThemeNavigationController(rootViewController: viewController)
    }

}
