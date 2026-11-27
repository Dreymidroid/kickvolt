/// Which editor's 4-step guide is selected on `HowToScreen` (M8 §4.4).
enum HowToTab {
  capCut('CapCut'),
  vn('VN');

  const HowToTab(this.label);

  final String label;
}
