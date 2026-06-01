//
//  ColorGrade.swift
//  CoreDesign
//
//  Created by 王晓龙 on 2025/2/1.
//

import Foundation
import SwiftUI

/// brand
#if Blossom
public extension Color {
    static let brand0 = Color("blossom-brand-0", bundle: .module)
    static let brand1 = Color("blossom-brand-1", bundle: .module)
    static let brand2 = Color("blossom-brand-2", bundle: .module)
    static let brand3 = Color("blossom-brand-3", bundle: .module)
    static let brand4 = Color("blossom-brand-4", bundle: .module)
    static let brand5 = Color("blossom-brand-5", bundle: .module)
    static let brand6 = Color("blossom-brand-6", bundle: .module)
    static let brand7 = Color("blossom-brand-7", bundle: .module)
    static let brand8 = Color("blossom-brand-8", bundle: .module)
    static let brand9 = Color("blossom-brand-9", bundle: .module)
}
#else
public extension Color {
    static let brand0 = Color("brand-0", bundle: .module)
    static let brand1 = Color("brand-1", bundle: .module)
    static let brand2 = Color("brand-2", bundle: .module)
    static let brand3 = Color("brand-3", bundle: .module)
    static let brand4 = Color("brand-4", bundle: .module)
    static let brand5 = Color("brand-5", bundle: .module)
    static let brand6 = Color("brand-6", bundle: .module)
    static let brand7 = Color("brand-7", bundle: .module)
    static let brand8 = Color("brand-8", bundle: .module)
    static let brand9 = Color("brand-9", bundle: .module)
}
#endif

/// amber
public extension Color {
    static let amber0 = Color("amber-0", bundle: .module)
    static let amber1 = Color("amber-1", bundle: .module)
    static let amber2 = Color("amber-2", bundle: .module)
    static let amber3 = Color("amber-3", bundle: .module)
    static let amber4 = Color("amber-4", bundle: .module)
    static let amber5 = Color("amber-5", bundle: .module)
    static let amber6 = Color("amber-6", bundle: .module)
    static let amber7 = Color("amber-7", bundle: .module)
    static let amber8 = Color("amber-8", bundle: .module)
    static let amber9 = Color("amber-9", bundle: .module)
}

/// blue
public extension Color {
    static let blue0 = Color("blue-0", bundle: .module)
    static let blue1 = Color("blue-1", bundle: .module)
    static let blue2 = Color("blue-2", bundle: .module)
    static let blue3 = Color("blue-3", bundle: .module)
    static let blue4 = Color("blue-4", bundle: .module)
    static let blue5 = Color("blue-5", bundle: .module)
    static let blue6 = Color("blue-6", bundle: .module)
    static let blue7 = Color("blue-7", bundle: .module)
    static let blue8 = Color("blue-8", bundle: .module)
    static let blue9 = Color("blue-9", bundle: .module)
}

/// cyan
public extension Color {
    static let cyan0 = Color("cyan-0", bundle: .module)
    static let cyan1 = Color("cyan-1", bundle: .module)
    static let cyan2 = Color("cyan-2", bundle: .module)
    static let cyan3 = Color("cyan-3", bundle: .module)
    static let cyan4 = Color("cyan-4", bundle: .module)
    static let cyan5 = Color("cyan-5", bundle: .module)
    static let cyan6 = Color("cyan-6", bundle: .module)
    static let cyan7 = Color("cyan-7", bundle: .module)
    static let cyan8 = Color("cyan-8", bundle: .module)
    static let cyan9 = Color("cyan-9", bundle: .module)
}

/// green
public extension Color {
    static let green0 = Color("green-0", bundle: .module)
    static let green1 = Color("green-1", bundle: .module)
    static let green2 = Color("green-2", bundle: .module)
    static let green3 = Color("green-3", bundle: .module)
    static let green4 = Color("green-4", bundle: .module)
    static let green5 = Color("green-5", bundle: .module)
    static let green6 = Color("green-6", bundle: .module)
    static let green7 = Color("green-7", bundle: .module)
    static let green8 = Color("green-8", bundle: .module)
    static let green9 = Color("green-9", bundle: .module)
}

/// grey
public extension Color {
    static let grey0 = Color("grey-0", bundle: .module)
    static let grey1 = Color("grey-1", bundle: .module)
    static let grey2 = Color("grey-2", bundle: .module)
    static let grey3 = Color("grey-3", bundle: .module)
    static let grey4 = Color("grey-4", bundle: .module)
    static let grey5 = Color("grey-5", bundle: .module)
    static let grey6 = Color("grey-6", bundle: .module)
    static let grey7 = Color("grey-7", bundle: .module)
    static let grey8 = Color("grey-8", bundle: .module)
    static let grey9 = Color("grey-9", bundle: .module)
}

/// indigo
public extension Color {
    static let indigo0 = Color("indigo-0", bundle: .module)
    static let indigo1 = Color("indigo-1", bundle: .module)
    static let indigo2 = Color("indigo-2", bundle: .module)
    static let indigo3 = Color("indigo-3", bundle: .module)
    static let indigo4 = Color("indigo-4", bundle: .module)
    static let indigo5 = Color("indigo-5", bundle: .module)
    static let indigo6 = Color("indigo-6", bundle: .module)
    static let indigo7 = Color("indigo-7", bundle: .module)
    static let indigo8 = Color("indigo-8", bundle: .module)
    static let indigo9 = Color("indigo-9", bundle: .module)
}

/// light-blue
public extension Color {
    static let lightBlue0 = Color("light-blue-0", bundle: .module)
    static let lightBlue1 = Color("light-blue-1", bundle: .module)
    static let lightBlue2 = Color("light-blue-2", bundle: .module)
    static let lightBlue3 = Color("light-blue-3", bundle: .module)
    static let lightBlue4 = Color("light-blue-4", bundle: .module)
    static let lightBlue5 = Color("light-blue-5", bundle: .module)
    static let lightBlue6 = Color("light-blue-6", bundle: .module)
    static let lightBlue7 = Color("light-blue-7", bundle: .module)
    static let lightBlue8 = Color("light-blue-8", bundle: .module)
    static let lightBlue9 = Color("light-blue-9", bundle: .module)
}

/// light-green
public extension Color {
    static let lightGreen0 = Color("light-green-0", bundle: .module)
    static let lightGreen1 = Color("light-green-1", bundle: .module)
    static let lightGreen2 = Color("light-green-2", bundle: .module)
    static let lightGreen3 = Color("light-green-3", bundle: .module)
    static let lightGreen4 = Color("light-green-4", bundle: .module)
    static let lightGreen5 = Color("light-green-5", bundle: .module)
    static let lightGreen6 = Color("light-green-6", bundle: .module)
    static let lightGreen7 = Color("light-green-7", bundle: .module)
    static let lightGreen8 = Color("light-green-8", bundle: .module)
    static let lightGreen9 = Color("light-green-9", bundle: .module)
}

/// lime
public extension Color {
    static let lime0 = Color("lime-0", bundle: .module)
    static let lime1 = Color("lime-1", bundle: .module)
    static let lime2 = Color("lime-2", bundle: .module)
    static let lime3 = Color("lime-3", bundle: .module)
    static let lime4 = Color("lime-4", bundle: .module)
    static let lime5 = Color("lime-5", bundle: .module)
    static let lime6 = Color("lime-6", bundle: .module)
    static let lime7 = Color("lime-7", bundle: .module)
    static let lime8 = Color("lime-8", bundle: .module)
    static let lime9 = Color("lime-9", bundle: .module)
}

/// orange
public extension Color {
    static let orange0 = Color("orange-0", bundle: .module)
    static let orange1 = Color("orange-1", bundle: .module)
    static let orange2 = Color("orange-2", bundle: .module)
    static let orange3 = Color("orange-3", bundle: .module)
    static let orange4 = Color("orange-4", bundle: .module)
    static let orange5 = Color("orange-5", bundle: .module)
    static let orange6 = Color("orange-6", bundle: .module)
    static let orange7 = Color("orange-7", bundle: .module)
    static let orange8 = Color("orange-8", bundle: .module)
    static let orange9 = Color("orange-9", bundle: .module)
}

/// pink
public extension Color {
    static let pink0 = Color("pink-0", bundle: .module)
    static let pink1 = Color("pink-1", bundle: .module)
    static let pink2 = Color("pink-2", bundle: .module)
    static let pink3 = Color("pink-3", bundle: .module)
    static let pink4 = Color("pink-4", bundle: .module)
    static let pink5 = Color("pink-5", bundle: .module)
    static let pink6 = Color("pink-6", bundle: .module)
    static let pink7 = Color("pink-7", bundle: .module)
    static let pink8 = Color("pink-8", bundle: .module)
    static let pink9 = Color("pink-9", bundle: .module)
}

/// purple
public extension Color {
    static let purple0 = Color("purple-0", bundle: .module)
    static let purple1 = Color("purple-1", bundle: .module)
    static let purple2 = Color("purple-2", bundle: .module)
    static let purple3 = Color("purple-3", bundle: .module)
    static let purple4 = Color("purple-4", bundle: .module)
    static let purple5 = Color("purple-5", bundle: .module)
    static let purple6 = Color("purple-6", bundle: .module)
    static let purple7 = Color("purple-7", bundle: .module)
    static let purple8 = Color("purple-8", bundle: .module)
    static let purple9 = Color("purple-9", bundle: .module)
}

/// red
public extension Color {
    static let red0 = Color("red-0", bundle: .module)
    static let red1 = Color("red-1", bundle: .module)
    static let red2 = Color("red-2", bundle: .module)
    static let red3 = Color("red-3", bundle: .module)
    static let red4 = Color("red-4", bundle: .module)
    static let red5 = Color("red-5", bundle: .module)
    static let red6 = Color("red-6", bundle: .module)
    static let red7 = Color("red-7", bundle: .module)
    static let red8 = Color("red-8", bundle: .module)
    static let red9 = Color("red-9", bundle: .module)
}

/// teal
public extension Color {
    static let teal0 = Color("teal-0", bundle: .module)
    static let teal1 = Color("teal-1", bundle: .module)
    static let teal2 = Color("teal-2", bundle: .module)
    static let teal3 = Color("teal-3", bundle: .module)
    static let teal4 = Color("teal-4", bundle: .module)
    static let teal5 = Color("teal-5", bundle: .module)
    static let teal6 = Color("teal-6", bundle: .module)
    static let teal7 = Color("teal-7", bundle: .module)
    static let teal8 = Color("teal-8", bundle: .module)
    static let teal9 = Color("teal-9", bundle: .module)
}

/// violet
public extension Color {
    static let violet0 = Color("violet-0", bundle: .module)
    static let violet1 = Color("violet-1", bundle: .module)
    static let violet2 = Color("violet-2", bundle: .module)
    static let violet3 = Color("violet-3", bundle: .module)
    static let violet4 = Color("violet-4", bundle: .module)
    static let violet5 = Color("violet-5", bundle: .module)
    static let violet6 = Color("violet-6", bundle: .module)
    static let violet7 = Color("violet-7", bundle: .module)
    static let violet8 = Color("violet-8", bundle: .module)
    static let violet9 = Color("violet-9", bundle: .module)
}

/// yellow
public extension Color {
    static let yellow0 = Color("yellow-0", bundle: .module)
    static let yellow1 = Color("yellow-1", bundle: .module)
    static let yellow2 = Color("yellow-2", bundle: .module)
    static let yellow3 = Color("yellow-3", bundle: .module)
    static let yellow4 = Color("yellow-4", bundle: .module)
    static let yellow5 = Color("yellow-5", bundle: .module)
    static let yellow6 = Color("yellow-6", bundle: .module)
    static let yellow7 = Color("yellow-7", bundle: .module)
    static let yellow8 = Color("yellow-8", bundle: .module)
    static let yellow9 = Color("yellow-9", bundle: .module)
}
