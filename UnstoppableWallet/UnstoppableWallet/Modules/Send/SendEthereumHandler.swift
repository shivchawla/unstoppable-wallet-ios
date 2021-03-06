import Foundation
import RxSwift
import EthereumKit
import FeeRateKit
import Erc20Kit
import HsToolKit

class SendEthereumHandler {
    private var gasDisposeBag = DisposeBag()
    weak var delegate: ISendHandlerDelegate?

    private let interactor: ISendEthereumInteractor

    private let amountModule: ISendAmountModule
    private let addressModule: ISendAddressModule
    private let feePriorityModule: ISendFeePriorityModule
    private let feeModule: ISendFeeModule

    private var estimateGasLimitState: FeeState = .zero

    init(interactor: ISendEthereumInteractor, amountModule: ISendAmountModule, addressModule: ISendAddressModule, feeModule: ISendFeeModule, feePriorityModule: ISendFeePriorityModule) {
        self.interactor = interactor
        self.amountModule = amountModule
        self.addressModule = addressModule
        self.feeModule = feeModule
        self.feePriorityModule = feePriorityModule
    }

    @discardableResult private func syncValidation() -> Bool {
        var success = false

        do {
            _ = try amountModule.validAmount()
            try addressModule.validateAddress()

            delegate?.onChange(isValid: feeModule.isValid && feePriorityModule.feeRateState.isValid && estimateGasLimitState.isValid)

            success = true
        } catch {
            delegate?.onChange(isValid: false)
        }

        return success
    }

    private func processFee(error: Error) {
        feeModule.set(externalError: error)
    }

    private func syncState() {
        let loading = feePriorityModule.feeRateState.isLoading || estimateGasLimitState.isLoading

        amountModule.set(loading: loading)
        feeModule.set(loading: loading)

        guard !loading else {
            return
        }

        if case let .error(error) = feePriorityModule.feeRateState {
            feeModule.set(fee: 0)

            processFee(error: error)
        } else if case let .error(error) = estimateGasLimitState {
            feeModule.set(fee: 0)

            processFee(error: error)
        } else if case let .value(feeRateValue) = feePriorityModule.feeRateState, case let .value(estimateGasLimitValue) = estimateGasLimitState {
            amountModule.set(availableBalance: interactor.availableBalance(gasPrice: feeRateValue, gasLimit: estimateGasLimitValue))

            feeModule.set(externalError: nil)
            feeModule.set(fee: interactor.fee(gasPrice: feeRateValue, gasLimit: estimateGasLimitValue))
        }
    }

    private func syncEstimateGasLimit() {
        gasDisposeBag = DisposeBag()

        estimateGasLimitState = .loading
        syncState()

        interactor.estimateGasLimit(to: try? addressModule.validAddress(), value: amountModule.currentAmount, gasPrice: feePriorityModule.feeRate)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .observeOn(MainScheduler.instance)
                .subscribe(onSuccess: onReceive, onError: onGasLimitError)
                .disposed(by: gasDisposeBag)
    }

}

extension SendEthereumHandler: ISendHandler {

    func onViewDidLoad() {
        feePriorityModule.fetchFeeRate()

        amountModule.set(minimumRequiredBalance: interactor.minimumRequiredBalance)
        if let minimumSpendableAmount = interactor.minimumSpendableAmount {
            amountModule.set(minimumAmount: minimumSpendableAmount)
        }

        feeModule.set(availableFeeBalance: interactor.ethereumBalance)
        syncState()

        syncEstimateGasLimit()
    }

    func showKeyboard() {
        amountModule.showKeyboard()
    }

    func confirmationViewItems() throws -> [ISendConfirmationViewItemNew] {
        [
            SendConfirmationAmountViewItem(primaryInfo: try amountModule.primaryAmountInfo(), secondaryInfo: try amountModule.secondaryAmountInfo(), receiver: try addressModule.validAddress()),
            SendConfirmationDurationViewItem(timeInterval: feePriorityModule.duration),
            SendConfirmationFeeViewItem(primaryInfo: feeModule.primaryAmountInfo, secondaryInfo: feeModule.secondaryAmountInfo)
        ]
    }

    func sync() {
        if feePriorityModule.feeRateState.isError || estimateGasLimitState.isError {
            feePriorityModule.fetchFeeRate()
            syncEstimateGasLimit()
        }
    }

    func sync(rateValue: Decimal?) {
        amountModule.set(rateValue: rateValue)
    }

    func sync(inputType: SendInputType) {
        amountModule.set(inputType: inputType)
        feeModule.update(inputType: inputType)
    }

    func sendSingle(logger: Logger) throws -> Single<Void> {
        guard let feeRate = feePriorityModule.feeRate, case let .value(gasLimit) = estimateGasLimitState else {
            throw SendTransactionError.noFee
        }
        return interactor.sendSingle(amount: try amountModule.validAmount(), address: try addressModule.validAddress(), gasPrice: feeRate, gasLimit: gasLimit, logger: logger)
    }

}

extension SendEthereumHandler: ISendAmountDelegate {

    func onChangeAmount() {
        if syncValidation() {
            syncEstimateGasLimit()
        }
    }

    func onChange(inputType: SendInputType) {
        feeModule.update(inputType: inputType)
    }

}

extension SendEthereumHandler: ISendAddressDelegate {

    func validate(address: String) throws {
        try interactor.validate(address: address)
    }

    func onUpdateAddress() {
        if syncValidation() {
            syncEstimateGasLimit()
        }
    }

    func onUpdate(amount: Decimal) {
        amountModule.set(amount: amount)
    }

}

extension SendEthereumHandler: ISendFeePriorityDelegate {

    func onUpdateFeePriority() {
        syncState()
        if syncValidation() {
            syncEstimateGasLimit()
        }
    }

}

extension SendEthereumHandler {

    func onReceive(gasLimit: Int) {
        estimateGasLimitState = .value(gasLimit)

        syncState()
        syncValidation()
    }

    func onGasLimitError(_ error: Error) {
        estimateGasLimitState = .error(error.convertedError)

        syncState()
        syncValidation()
    }

}
