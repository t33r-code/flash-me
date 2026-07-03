// Progressive question reveal (#215).
//
// In a multi-question card, questions reveal one at a time: the first is always
// shown expanded, and each later question stays collapsed (label only) until the
// one before it has been answered. Answered questions never collapse again.
//
// [index] is the 0-based position of the question in the card. [answered] holds
// the indices of questions that have received an answer this visit. A question
// is expanded when it is the first one, or when its immediate predecessor has
// been answered.
bool isQuestionExpanded(int index, Set<int> answered) =>
    index == 0 || answered.contains(index - 1);