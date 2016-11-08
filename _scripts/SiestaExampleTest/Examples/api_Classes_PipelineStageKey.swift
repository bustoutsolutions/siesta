import Siesta

private
//══════ api_Classes_PipelineStageKey:0 ══════
// ... → func api_Classes_PipelineStageKey(service: Service) {
extension PipelineStageKey {
  static let
    munging   = PipelineStageKey(description: "munging"),
    twiddling = PipelineStageKey(description: "twiddling")
}

func api_Classes_PipelineStageKey(service: Service) {

service.configure {
    $0.pipeline.order = [.rawData, .munging, .twiddling, .cleanup]
}
//════════════════════════════════════

}
