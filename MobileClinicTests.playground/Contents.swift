import UIKit
import Accelerate
import PlaygroundSupport
import XCPlayground

func readCSV(fileName:String, fileType: String) -> String!{
    guard let filepath = Bundle.main.path(forResource: fileName, ofType: fileType)
        else {
            return nil
    }
    do {
        var contents = try String(contentsOfFile: filepath, encoding: .utf8)
        return contents
    } catch {
        print("File Read Error for file \(filepath)")
        return nil
    }
}

func fft(frameOfSamples: [Float]) -> [Float] {
    
    let frameCount = frameOfSamples.count
    
    let reals = UnsafeMutableBufferPointer<Float>.allocate(capacity: frameCount)
    defer {reals.deallocate()}
    let imags =  UnsafeMutableBufferPointer<Float>.allocate(capacity: frameCount)
    defer {imags.deallocate()}
    
    _ = reals.initialize(from: frameOfSamples)
    imags.initialize(repeating: 0.0)
    
    var complexBuffer = DSPSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)
    
    let log2Size = Int(log2(Float(frameCount)))
    
    guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2Size), FFTRadix(kFFTRadix2)) else {
        return []
    }
    
    defer {vDSP_destroy_fftsetup(fftSetup)}
    
    // Perform a forward FFT
    vDSP_fft_zip(fftSetup, &complexBuffer, 1, vDSP_Length(log2Size), FFTDirection(FFT_FORWARD))
    
    
//    //transform realFloats to "traditional" periodogram
//    let array_exponentials = UnsafeMutablePointer<Float>.allocate(capacity: reals.count)
//    array_exponentials.initialize(to: 2.0)
//
//    var exp_output = UnsafeMutablePointer<Float>.allocate(capacity: reals.count)
//    var real_unsafe_pointer = UnsafePointer<Float>(Array(reals))
//
//
//    let unsafe_mutable_pointer_for_size = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
//    unsafe_mutable_pointer_for_size.initialize(to: Int32(reals.count))
//
//    let unsafe_pointer_for_size = UnsafePointer(unsafe_mutable_pointer_for_size)
//
//
//    vvpowf(exp_output, array_exponentials, real_unsafe_pointer, unsafe_pointer_for_size)
    
    
    var realFloats = Array(reals)
    var imaginaryFloats = Array(imags)
    
    var float_squared: [Float] = []

    var exponentials: [Float] = [Float](repeating: 2, count: realFloats.count)
    var z = [Float](repeating: 0, count: realFloats.count)
    var n = Int32(realFloats.count)
    
    vvpowf(&z, &exponentials, &realFloats, &n)
    
    return z.map{$0 * Float(Float(2.0)/Float(reals.count))}
}

func linearly_interpolate(input: [CGFloat]) -> [Float] {
    
    //remove all NaN values from the array
    var time: [Double] = [] //[Array(0...(input.count-1)).map{Double($0)}]
    var signal: [Double] = []
    
    var i: Double = 0.0
    
    for val in input {
        if (!val.isNaN) {
            signal.append(Double(val))
            time.append(i)
        }
        
        i += 1
    }
    
    //linearly interpolate the NaN values to give constant ∆t = 1
    
    var interpolated = [Double](repeating: 0,
                                count: Int(time[time.count-1]) + 1)
    
    let stride = vDSP_Stride(1)
    
    vDSP_vgenpD(signal, stride,
                time, stride,
                &interpolated, stride,
                vDSP_Length(interpolated.count),
                vDSP_Length(signal.count))
    
    var interpolized_signal_float: [Float] = interpolated.map{Float($0)}
    
    return interpolized_signal_float
}

func total_sum_signals(input: [[Float]], length: Int) -> [Float] {
    var original: [[Float]] = input
    var summed: [Float] = []
    
    var min_length_over_signals = Int(original.map{$0.count}.min()!)
    
    
    for index in 0..<min_length_over_signals {
        var value_sum: Float = 0
        
        for signal in original {
            value_sum += signal[index]
        }
        
        summed.append(value_sum)
    }
    
    return summed
}

func normalize(signal: [Float]) -> [Float] {
    var input = signal
    
    var max = input.max()
    
    for i in 0..<input.count {
        input[i] = input[i]/Float(max!)
    }
    
    return input
}

func compute_periodogram(frameOfSamples: [Float]) -> [Float] {
    
    let frameCount = frameOfSamples.count
    
    let reals = UnsafeMutableBufferPointer<Float>.allocate(capacity: frameCount)
    defer {reals.deallocate()}
    let imags =  UnsafeMutableBufferPointer<Float>.allocate(capacity: frameCount)
    defer {imags.deallocate()}
    
    _ = reals.initialize(from: frameOfSamples)
    imags.initialize(repeating: 0.0)
    
    var complexBuffer = DSPSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)
    
    let log2Size = Int(log2(Float(frameCount)))
    
    guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2Size), FFTRadix(kFFTRadix2)) else {
        return []
    }
    
    defer {vDSP_destroy_fftsetup(fftSetup)}
    
    // Perform a forward FFT
    vDSP_fft_zip(fftSetup, &complexBuffer, 1, vDSP_Length(log2Size), FFTDirection(FFT_FORWARD))
    
    
    //    //transform realFloats to "traditional" periodogram
    //    let array_exponentials = UnsafeMutablePointer<Float>.allocate(capacity: reals.count)
    //    array_exponentials.initialize(to: 2.0)
    //
    //    var exp_output = UnsafeMutablePointer<Float>.allocate(capacity: reals.count)
    //    var real_unsafe_pointer = UnsafePointer<Float>(Array(reals))
    //
    //
    //    let unsafe_mutable_pointer_for_size = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    //    unsafe_mutable_pointer_for_size.initialize(to: Int32(reals.count))
    //
    //    let unsafe_pointer_for_size = UnsafePointer(unsafe_mutable_pointer_for_size)
    //
    //
    //    vvpowf(exp_output, array_exponentials, real_unsafe_pointer, unsafe_pointer_for_size)
    
    
    var realFloats = Array(reals)
    var imaginaryFloats = Array(imags)
    
    var float_squared: [Float] = []
    
    var exponentials: [Float] = [Float](repeating: 2, count: realFloats.count)
    var z = [Float](repeating: 0, count: realFloats.count)
    var n = Int32(realFloats.count)
    
    vvpowf(&z, &exponentials, &realFloats, &n)
    
    return z.map{$0 * Float(Float(2.0)/Float(reals.count))}
}

func determine_squats(periodogram: [Float]) -> Int{
    
    //remove the element at index 0 in case it is indefinite.
    
    var pgram = periodogram
    
    pgram.remove(at: 0)
    
    //find max
    
    var max = pgram.max()
    var maxIdx = pgram.firstIndex(of: max!)!
    
    maxIdx += 1 // since we removed the first element.
    
    var frames = pgram.count
    
    var max_freq = maxIdx/frames
    
    var period = 1/max_freq
    
    var num_squats = frames/period
    
    return num_squats
}


/**
 Preconditions: data is a CSV of rows with column elements seperated by ,
                col_idx is a valid index of each column
 
 Postconditions: returns a tuple with the (signal, time_series)
 **/
func get_signal_from_csv(data: String, col_idx: Int) -> ([Double], [Double]) {
    var result: [[String]] = []
    let rows = data.components(separatedBy: "\n")
    
    var time: [Double] = []
    var signal: [Double] = []
    
    var time_counter: Double = 0
    
    var first_row: Bool = true
    
    for row in rows {
        let columns = row.components(separatedBy: ",")
        result.append(columns)
        
        if (!first_row && columns.count > col_idx) {

            if(columns[col_idx] == " nan") {
                //signal.append(Float.nan)
            } else {
                
                if let num = NumberFormatter().number(from: columns[col_idx]) {
                    //print(num.floatValue)
                    signal.append(num.doubleValue)
                    time.append(time_counter)
                } else {
                    print(columns[col_idx])
                }
            }
            
            time_counter += 1
        } else {
            print(row)
        }
        
        first_row = false
        
    }
    return (signal, time)
}

// Function to calculate the arithmetic mean
func arithmeticMean(array: [CGFloat]) -> CGFloat {
    var total: CGFloat = 0
    for number in array {
        total += number
    }
    return total / CGFloat(array.count)
}

// Function to extract some range from an array
func subArray<T>(array: [T], s: Int, e: Int) -> [T] {
    if e > array.count {
        return []
    }
    return Array(array[s..<min(e, array.count)])
}

func movingAverageFilter(filterWidth: Int, inputData: [CGFloat]) -> [CGFloat]{
    
    var filtered_signal: [CGFloat] = []
    
    for (index, value) in inputData.enumerated() {
        if ( (index > Int(filterWidth/2)) && (index < Int(inputData.count - filterWidth/2))) {
            var selection_for_average = subArray(array: inputData, s: Int(index-filterWidth/2), e: Int(index + filterWidth/2));
            var average = arithmeticMean(array: selection_for_average);
            filtered_signal.append(average);
        }
    }
    return filtered_signal;
}

//func get_multiple_columns_from_csv(data: String) -> [[String]] {
//
//    return nil
//}

var csv_content = readCSV(fileName: "all_signals_2", fileType: "csv")!

var signal_from_csv = get_signal_from_csv(data: csv_content, col_idx: 15)

var time_signal = signal_from_csv.1

var signal = signal_from_csv.0

var filtered = movingAverageFilter(filterWidth: 7, inputData: signal.map{CGFloat($0)})

var num_squats = determine_squats(periodogram: filtered.map{Float($0)})

print("Patient squatted \(num_squats) times")

let documentUrl = XCPlaygroundSharedDataDirectoryURL.appendingPathComponent("Combined_iPhone_pgram.csv")

var csv_body = "time, pgram\n"

var lengths = [time_signal.count, filtered.count]

var max_len = Int(lengths.max()!)

for var i in 0..<max_len {
    
    var row = "\n"
    
    if i < filtered.count && i < time_signal.count {
        row = "\(time_signal[i]),\(filtered[i])\n"
    } else if(i < filtered.count) {
        row = ",\(filtered[i])\n"
    } else {
        row = "\(time_signal[i]),\n"
    }
    
    csv_body.append(row)
}


let data = Data(csv_body.utf8)

do {
    try data.write(to: documentUrl!)
    print("data written")
} catch {
    print(error)
}


