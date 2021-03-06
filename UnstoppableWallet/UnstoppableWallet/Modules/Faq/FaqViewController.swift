import UIKit
import SnapKit
import ThemeKit
import SectionsTableView
import HUD
import RxSwift

class FaqViewController: ThemeViewController {
    private static let spinnerRadius: CGFloat = 8
    private static let spinnerLineWidth: CGFloat = 2

    private let viewModel: FaqViewModel

    private let tableView = SectionsTableView(style: .grouped)

    private let spinner = HUDProgressView(
            strokeLineWidth: FaqViewController.spinnerLineWidth,
            radius: FaqViewController.spinnerRadius,
            strokeColor: .themeGray
    )

    private let errorLabel = UILabel()
    private var items = [FaqService.Item]()

    private let disposeBag = DisposeBag()

    init(viewModel: FaqViewModel) {
        self.viewModel = viewModel

        super.init()

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "faq.title".localized

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.sectionDataSource = self

        tableView.registerCell(forClass: FaqCell.self)

        view.addSubview(spinner)
        spinner.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
            maker.width.height.equalTo(FaqViewController.spinnerRadius * 2 + FaqViewController.spinnerLineWidth)
        }

        view.addSubview(errorLabel)
        errorLabel.snp.makeConstraints { maker in
            maker.center.equalToSuperview()
        }

        errorLabel.font = .subhead2
        errorLabel.textColor = .themeGray

        viewModel.itemsDriver
                .drive(onNext: { [weak self] items in
                    self?.items = items
                    self?.tableView.reload()
                })
                .disposed(by: disposeBag)

        viewModel.loadingDriver
                .drive(onNext: { [weak self] loading in
                    self?.setSpinner(visible: loading)
                })
                .disposed(by: disposeBag)

        viewModel.errorDriver
                .drive(onNext: { [weak self] error in
                    self?.errorLabel.text = error?.smartDescription
                })
                .disposed(by: disposeBag)

        tableView.buildSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        tableView.deselectCell(withCoordinator: transitionCoordinator, animated: animated)
    }

    private func setSpinner(visible: Bool) {
        if visible {
            spinner.isHidden = false
            spinner.startAnimating()
        } else {
            spinner.isHidden = true
            spinner.stopAnimating()
        }
    }

}

extension FaqViewController: SectionsDataSource {

    public func buildSections() -> [SectionProtocol] {
        [
            Section(
                    id: "main",
                    headerState: .margin(height: .margin3x),
                    footerState: .margin(height: .margin8x),
                    rows: items.enumerated().map { index, item in
                        let last = index == items.count - 1

                        return Row<FaqCell>(
                                id: "faq_\(index)",
                                dynamicHeight: { containerWidth in
                                    FaqCell.height(containerWidth: containerWidth, text: item.text)
                                },
                                bind: { cell, _ in
                                    cell.set(backgroundStyle: .lawrence, bottomSeparator: last)
                                    cell.title = item.text
                                },
                                action: { [weak self] _ in
                                    guard let url = item.url else {
                                        return
                                    }

                                    let module = MarkdownModule.viewController(url: url)
                                    self?.navigationController?.pushViewController(module, animated: true)
                                }
                        )
                    }
            )
        ]
    }

}
