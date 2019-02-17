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

func linearly_interpolate(input_x: [Double], input_y: [Double]) -> [Double]{
    
    var new_values = [Double](repeating: 0,
                              count: Int(input_x[input_x.count-1]) + 1)
    
    let stride = vDSP_Stride(1)
    
    vDSP_vgenpD(input_y, stride,
                input_x, stride,
                &new_values, stride,
                vDSP_Length(new_values.count),
                vDSP_Length(input_y.count))
    
    return new_values
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

//func get_multiple_columns_from_csv(data: String) -> [[String]] {
//
//    return nil
//}

var csv_content = readCSV(fileName: "all-signals", fileType: "csv")!

var signal_from_csv = get_signal_from_csv(data: csv_content, col_idx: 1)

var time_signal = signal_from_csv.1

var signal = signal_from_csv.0

//print(time_signal)

//print(signal)

let output = linearly_interpolate(input_x: time_signal, input_y: signal)

print(output)

let pgram = fft(frameOfSamples: output.map{Float($0) ?? 0})

let documentUrl = XCPlaygroundSharedDataDirectoryURL.appendingPathComponent("2-playground_interpolation_and_pgram.csv")

var csv_body = "pgram, linear-interpolation\n"

var lengths = [output.count, pgram.count]

var max_len = Int(lengths.max()!)

for var i in 0..<max_len {
    
    var row = "\n"
    
    if i < output.count && i < pgram.count {
        row = "\(pgram[i]),\(output[i])\n"
    } else if(i < output.count) {
        row = ",\(output[i])\n"
    } else {
        row = "\(pgram[i]),\n"
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


