import UIKit
import Accelerate
import PlaygroundSupport
import XCPlayground
import Foundation

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

func determine_squats(periodogram: [Double], peakX: [Int], peakY: [Double]) -> Double{
    
    //remove the element at index 0 in case it is indefinite.
    
    var max = peakY.max()!
    var maxIdx = peakX[peakY.index(of: max)!]
    
    
    var pgram = periodogram
    
    var frames = pgram.count
    
    var max_freq = Double(maxIdx)/Double(frames)
    
    var period = 1/Double(max_freq)
    
    var num_squats = Double(frames)/Double(period)
    
    return num_squats.rounded()
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

// Function to calculate the arithmetic mean
func arithmeticMean(array: [Double]) -> Double {
    var total: Double = 0
    for number in array {
        total += number
    }
    return total / Double(array.count)
}

// Function to extract some range from an array
func subArray<T>(array: [T], s: Int, e: Int) -> [T] {
    if e > array.count {
        return []
    }
    return Array(array[s..<min(e, array.count)])
}

// Function to calculate the standard deviation
func standardDeviation(array: [Double]) -> Double
{
    let length = Double(array.count)
    let avg = array.reduce(0, {$0 + $1}) / length
    let sumOfSquaredAvgDiff = array.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
    return sqrt(sumOfSquaredAvgDiff / length)
}

func detect_peaks(y: [Double]) -> ([Int], [Double]) {
    //window of size 3
    
    var peakIndexes: [Int] = []
    var peakY: [Double] = []
    
    for index in 1..<(y.count-1) {
        if(y[index] > y[index-1] && y[index] > y[index+1]) {
            //point is a peak
            peakIndexes.append(index)
            peakY.append(y[index])
        }
    }
    return (peakIndexes, peakY)
}

// Smooth z-score thresholding filter
func ThresholdingAlgo(y: [Double],lag: Int,threshold: Double,influence: Double) -> ([Int], [Double]) {
    
    // Create arrays
    var signals   = Array(repeating: 0, count: y.count)
    var filteredY = Array(repeating: 0.0, count: y.count)
    var avgFilter = Array(repeating: 0.0, count: y.count)
    var stdFilter = Array(repeating: 0.0, count: y.count)
    
    // Initialise variables
    for i in 0...lag-1 {
        signals[i] = 0
        filteredY[i] = y[i]
    }
    
    // Start filter
    avgFilter[lag-1] = arithmeticMean(array: subArray(array: y, s: 0, e: lag-1))
    stdFilter[lag-1] = standardDeviation(array: subArray(array: y, s: 0, e: lag-1))
    
    for i in lag...y.count-1 {
        if abs(y[i] - avgFilter[i-1]) > threshold*stdFilter[i-1] {
            if y[i] > avgFilter[i-1] {
                signals[i] = 1      // Positive signal
            } else {
                // Negative signals are turned off for this application
                //signals[i] = -1       // Negative signal
            }
            filteredY[i] = influence*y[i] + (1-influence)*filteredY[i-1]
        } else {
            signals[i] = 0          // No signal
            filteredY[i] = y[i]
        }
        // Adjust the filters
        avgFilter[i] = arithmeticMean(array: subArray(array: filteredY, s: i-lag, e: i))
        stdFilter[i] = standardDeviation(array: subArray(array: filteredY, s: i-lag, e: i))
    }
    
    var peakIndexes: [Int] = []
    var peakY: [Double] = []
    
    for index in 0..<y.count {
        if(signals[index] == 1) {
            peakIndexes.append(index)
            peakY.append(y[index])
        }
    }
    
    //return (signals,avgFilter,stdFilter)
    return (peakIndexes, peakY)
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

var csv_content = readCSV(fileName: "all_signals_4", fileType: "csv")!

var signal_from_csv = get_signal_from_csv(data: csv_content, col_idx: 15)

var time_signal = signal_from_csv.1

var signal = signal_from_csv.0

signal = Array(signal.prefix(Int(signal.count/2)))
time_signal = Array(time_signal.prefix(Int(time_signal.count/2)))

var filtered = movingAverageFilter(filterWidth: 7, inputData: signal.map{CGFloat($0)})

//let peakCoordinates = ThresholdingAlgo(y: filtered.map{Double($0)}, lag: 3, threshold: 0.5, influence: 0.8)

let peakCoordinates = detect_peaks(y: filtered.map{Double($0)})

var peakX = peakCoordinates.0
var peakY = peakCoordinates.1

var squats = determine_squats(periodogram: signal, peakX: peakX, peakY: peakY)

print(squats)

let documentUrl = XCPlaygroundSharedDataDirectoryURL.appendingPathComponent("Combined_iPhone_pgram.csv")

var csv_body = "pgram, peakX, peakY\n"

var lengths = [filtered.count, peakX.count, peakY.count]

var max_len = Int(lengths.max()!)

print(max_len)

print("\(filtered.count)")

print("\(peakX.count) -- \(peakY.count)")

for var i in 0..<max_len {
    
    var row = "\n"
    
    //assuming there are less values in signal than peaks
    
    if i < filtered.count && i < peakX.count {
        row = "\(filtered[i]),\(peakX[i]),\(peakY[i])\n"
    } else if(i < filtered.count) {
        row = "\(filtered[i]),,\n"
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


