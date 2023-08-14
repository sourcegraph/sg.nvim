// https://github.com/mitsuhiko/similar

use similar::TextDiff;

pub fn make_diff(left: &str, right: &str) -> serde_json::Value {
    let mut config = TextDiff::configure();
    config.algorithm(similar::Algorithm::Patience);
    config.newline_terminated(false);

    let diff = config.diff_lines(left, right);
    let changes = diff
        .ops()
        .iter()
        .flat_map(|op| diff.iter_inline_changes(op))
        .collect::<Vec<_>>();

    serde_json::to_value(changes).expect("to convert to json")
}
