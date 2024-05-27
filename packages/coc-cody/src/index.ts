import {
	type CancellationToken,
	type CompletionContext,
	type CompletionItem,
	type CompletionItemProvider,
	type CompletionList,
	type ExtensionContext,
	type LinesTextDocument,
	type Position,
	type ProviderResult,
	languages,
	workspace,
} from "coc.nvim";

class CodyCompletionItemProvider implements CompletionItemProvider {
	provideCompletionItems(
		_document: LinesTextDocument,
		_position: Position,
		_token: CancellationToken,
		_context?: CompletionContext | undefined,
	): ProviderResult<CompletionList | CompletionItem[]> {
		return new Promise((resolve) => {
			// Execute async function to resolve the promise,
			// perhaps there is an easier way to do this?
			(async () => {
				const { nvim } = workspace;
				const items = (await nvim.callAsync("sg#cody_request", [
					"ignored",
				])) as CompletionItem[];
				resolve({ isIncomplete: false, items });
			})();
		});
	}

	resolveCompletionItem?(
		_item: CompletionItem,
		_token: CancellationToken,
	): ProviderResult<CompletionItem> {
		return _item;
	}
}

export async function activate(context: ExtensionContext): Promise<void> {
	languages.registerCompletionItemProvider(
		"coc-cody-async-comp",
		"cody",
		null,
		new CodyCompletionItemProvider(),
		[".", " ", "(", "{"],
		100,
	);
}
