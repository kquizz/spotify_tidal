module ApplicationHelper
  # Helper to return the default hex for color i (1..10) so the input shows the initial value
  def get_color_default(i)
    defaults = {
      1 => "#FF5400",
      2 => "#FF6D00",
      3 => "#FF8500",
      4 => "#FF9100",
      5 => "#FF9E00",
      6 => "#00B4D8",
      7 => "#0096C7",
      8 => "#0077B6",
      9 => "#023E8A",
      10 => "#03045E"
    }
    defaults[i]
  end
end
