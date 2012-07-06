UndoManager = require 'undo-manager'
Buffer = require 'buffer'
Range = require 'range'

describe "UndoManager", ->
  [buffer, undoManager] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    undoManager = buffer.undoManager

  afterEach ->
    buffer.destroy()

  describe ".undo()", ->
    it "undoes the last change", ->
      buffer.change(new Range([0, 5], [0, 9]), '')
      buffer.insert([0, 6], 'h')
      buffer.insert([0, 10], 'y')
      expect(buffer.lineForRow(0)).toContain 'qshorty'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qshort'
      expect(buffer.lineForRow(0)).not.toContain 'qshorty'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qsort'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'quicksort'

    it "does not throw an exception when there is nothing to undo", ->
      undoManager.undo()

  describe ".redo()", ->
    beforeEach ->
      buffer.change(new Range([0, 5], [0, 9]), '')
      buffer.insert([0, 6], 'h')
      buffer.insert([0, 10], 'y')
      undoManager.undo()
      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qsort'

    it "redoes the last undone change", ->
      undoManager.redo()
      expect(buffer.lineForRow(0)).toContain 'qshort'

      undoManager.redo()
      expect(buffer.lineForRow(0)).toContain 'qshorty'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qshort'

    it "does not throw an exception when there is nothing to redo", ->
      undoManager.redo()
      undoManager.redo()
      undoManager.redo()

    it "discards the redo history when there is a new change following an undo", ->
      buffer.insert([0, 6], 'p')
      expect(buffer.getText()).toContain 'qsport'

      undoManager.redo()
      expect(buffer.getText()).toContain 'qsport'

  describe "startUndoBatch() / endUndoBatch()", ->
    it "causes changes in batch to be undone simultaneously and returns an array of ranges to select from undo and redo", ->
      buffer.insert([0, 0], "foo")

      ignoredRanges = [[[666, 666], [666, 666]], [[666, 666], [666, 666]]]
      beforeRanges = [[[1, 2], [1, 2]], [[1, 9], [1, 9]]]
      afterRanges =[[[1, 5], [1, 5]], [[1, 12], [1, 12]]]

      undoManager.startUndoBatch(beforeRanges)
      undoManager.startUndoBatch(ignoredRanges) # calls can be nested
      buffer.insert([1, 2], "111")
      buffer.insert([1, 9], "222")
      undoManager.endUndoBatch(ignoredRanges) # calls can be nested
      undoManager.endUndoBatch(afterRanges)

      expect(buffer.lineForRow(1)).toBe '  111var 222sort = function(items) {'

      ranges = undoManager.undo()
      expect(ranges).toBe beforeRanges
      expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'
      expect(buffer.lineForRow(0)).toContain 'foo'

      ranges = undoManager.undo()
      expect(ranges).toBeUndefined()

      expect(buffer.lineForRow(0)).not.toContain 'foo'

      ranges = undoManager.redo()
      expect(ranges).toBeUndefined()
      expect(buffer.lineForRow(0)).toContain 'foo'

      ranges = undoManager.redo()
      expect(ranges).toBe afterRanges
      expect(buffer.lineForRow(1)).toBe '  111var 222sort = function(items) {'

      ranges = undoManager.undo()
      expect(ranges).toBe beforeRanges
      expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'

    it "does not store empty batches", ->
      buffer.insert([0,0], "foo")
      undoManager.startUndoBatch()
      undoManager.endUndoBatch()

      undoManager.undo()
      expect(buffer.lineForRow(0)).not.toContain("foo")

