import Foundation
import Darwin
let args = CommandLine.arguments
let mode = Ranker.Mode(rawValue: args[1])!
let rows = try String(contentsOfFile: args[2], encoding:.utf8).split(separator:"\n").map { $0.components(separatedBy:"\t") }
func footprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    precondition(status == KERN_SUCCESS)
    return info.phys_footprint
}
let before = footprint()
let model = try Ranker(URL(fileURLWithPath:"Resources"), mode: mode)
let loaded = footprint()
var correct = [0,0], total = [0,0], microseconds = [Double]()
let start = clock()
for row in rows {
    let label = Int(row[5])!
    let left = row[3].split(separator:" ").map(String.init)
    let begin = DispatchTime.now().uptimeNanoseconds
    let predicted = model.choose(raw:row[0], composed:row[1], fallback:row[2], left:left, next:row[4])
    microseconds.append(Double(DispatchTime.now().uptimeNanoseconds-begin)/1000)
    if predicted == row[label == 1 ? 0 : 1] { correct[label] += 1 }
    total[label] += 1
}
let cpu = Double(clock()-start)/Double(CLOCKS_PER_SEC)
microseconds.sort()
print(mode.rawValue, "correct VI/EN",correct,"of",total,"p95 us",microseconds[microseconds.count*95/100],"loop CPU ms",cpu*1000)

print("model load footprint delta bytes", Int64(loaded)-Int64(before))
