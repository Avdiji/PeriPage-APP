enum PrinterStatus {
  disconnected('Disconnected'),
  connecting('Connecting'),
  idle('Ready'),
  printing('Printing'),
  waitingForPaper('Insert next sheet'),
  busy('Busy'),
  noPaper('No paper'),
  lowBattery('Low battery'),
  overheated('Overheated');

  final String label;
  const PrinterStatus(this.label);

  bool get isProblem => this == noPaper || this == lowBattery || this == overheated;
}
