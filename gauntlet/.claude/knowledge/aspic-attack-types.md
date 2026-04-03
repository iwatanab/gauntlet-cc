# ASPIC+ Attack Types

Source: Prakken & Modgil, ASPIC+ structured argumentation framework

## Three attack types

### Rebuttal
Attacks the conclusion of the argument directly.
Asserts that the claim is false or unsupported at the conclusion level.
Toulmin equivalent: attacks the claim.

Example: "The patient does not have low cardiac risk" is a rebuttal of
"deprioritise this patient."

### Undercutting
Attacks the inference rule — the warrant — connecting grounds to claim.
Does not deny the grounds or the conclusion outright.
Asserts that this inference from these grounds to this conclusion
is not valid in this case.
Toulmin equivalent: attacks the warrant.

Example: "Normal ECG alone does not reliably indicate low cardiac risk
in this population" undercuts the inference rule without denying the
ECG finding or the claim directly.

### Undermining
Attacks the evidential basis — the grounds — of the argument.
Asserts that the grounds are false, unreliable, or unrepresentative.
Toulmin equivalent: attacks the grounds.

Example: "The SpO2 reading is artefactual due to peripheral shutdown"
undermines the evidential basis without touching the warrant or claim.

## Extension semantics

### Preferred extension
The maximal set of arguments collectively acceptable without contradiction.
An argument is in the preferred extension if it defeats or avoids all attacks.

### Grounded extension
The most cautious acceptable set — only arguments that survive all possible
attack under the most sceptical reading.

### Reinstatement
If argument A is attacked by B, and B is itself defeated by C,
then A is reinstated. Its attacker was neutralised.
This is how answering a critical question restores the original argument's
standing. Reinstatement is a formal property — it must be computed, not
assessed holistically.

## Attack graph construction

Nodes: every argument and counter-argument in play.
Directed edges: attack relations between them.
Label each edge with the attack type.
Compute the preferred extension by finding the maximal conflict-free
and self-defending set of argument nodes.
The preferred extension is determined by the graph structure.
It is not a judgment about which arguments seem stronger.