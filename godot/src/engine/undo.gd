## Undo for the turn (single player): a snapshot before every order, up to a dozen, dropped when the turn ends or something random happens (a battle, a spy, an event answer:
## undoing past a roll of the dice would let a player look at the result and choose again).
class_name TBUndo
extends RefCounted

const MAX := 12
var stack: Array = []

func clear() -> void: stack.clear()
func can() -> bool: return not stack.is_empty()
func size() -> int: return stack.size()

func push(g: TBGame) -> void:
	stack.append(TBSave.snapshot(g))
	if stack.size() > MAX: stack.pop_front()

## the snapshot taken for an order that turned out to be refused
func drop_last() -> void:
	if not stack.is_empty(): stack.pop_back()

func undo(g: TBGame) -> bool:
	if stack.is_empty(): return false
	TBSave.restore(g, stack.pop_back())
	return true
