//
//  ViewController.swift
//  Combine-MVVM
//
//  Created by Vikas on 10/04/23.
//

import UIKit
import Combine

class ViewController: UIViewController {

    @IBOutlet weak var quoteLable: UILabel!
    @IBOutlet weak var refreshButton: UIButton!
    
    private let viewModel = QuoteViewModel()
    private let input: PassthroughSubject<QuoteViewModel.Input, Never> = .init()
    private var cancellable = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bind()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        input.send(.viewDidAppear)
    }
    
    func bind() {
        let output = viewModel.transform(input: input.eraseToAnyPublisher())
        
        output
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
            switch event {
            case .fetchQuoteDidFail(error: let error):
                self?.quoteLable.text = error.localizedDescription
            case .fetchQuoteDidSuccess(quote: let quote):
                self?.quoteLable.text = quote.content
            case .toggelButton(isEnabled: let isEnabled):
                self?.refreshButton.isEnabled = isEnabled
            }
        }.store(in: &cancellable)
    }

    @IBAction private func onTapRefresh(_ sender: UIButton) {
        input.send(.refreshButtonTapped)
    }

}

//MARK: ViewModel
class QuoteViewModel {
    
    enum Input {
        case viewDidAppear
        case refreshButtonTapped
    }
    
    enum Output {
        case fetchQuoteDidFail(error: Error)
        case fetchQuoteDidSuccess(quote: QuoteModel)
        case toggelButton(isEnabled: Bool)
    }
    
    private let quoteService: QuoteServiceInterface
    private let output: PassthroughSubject<Output, Never> = .init()
    private var cancellable = Set<AnyCancellable>()
    
    init(quoteService: QuoteServiceInterface = QuoteService()) {
        self.quoteService = quoteService
    }
    
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        input.sink { [weak self] event in
            switch event {
            case .viewDidAppear, .refreshButtonTapped:
                self?.handleGetRandomQuote()
            }
        }.store(in: &cancellable)
        
        return output.eraseToAnyPublisher()
    }
    
    private func handleGetRandomQuote() {
        output.send(.toggelButton(isEnabled: false))
        quoteService.getRandomQuote().sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.output.send(.fetchQuoteDidFail(error: error))
            }
        } receiveValue: { [weak self] quote in
            self?.output.send(.toggelButton(isEnabled: true))
            self?.output.send(.fetchQuoteDidSuccess(quote: quote))
        }.store(in: &cancellable)
    }
    
}

//MARK: Service/ Protocol
protocol QuoteServiceInterface {
    func getRandomQuote() -> AnyPublisher<QuoteModel, Error>
}

class QuoteService: QuoteServiceInterface {
    
    func getRandomQuote() -> AnyPublisher<QuoteModel, Error> {
        
        let url = URL(string: "https://api.quotable.io/random")!
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .catch { error in
                return Fail(error: error).eraseToAnyPublisher()
            }.map({$0.data})
            .decode(type: QuoteModel.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

//MARK: Data Model
struct QuoteModel: Decodable {
    let content: String
    let author: String
}
