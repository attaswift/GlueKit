//
//  HashingTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-25.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

private func TEST(_ string: String) -> Data {
    return Data(bytes: Array(string.utf8))
}

private func TEST(_ bytes: [UInt8]) -> Data {
    return Data(bytes: bytes)
}

private func TEST(_ data: Data) -> Data {
    return data
}

private func TEST0(_ string: String) -> Data {
    return Data(bytes: Array((string + "\0").utf8))
}

private func repeated(_ count: Int, _ data: Data) -> Data {
    var result = Data()
    for _ in 0 ..< count {
        result.append(data)
    }
    return result
}

private struct TestHashable: Hashable {
    let value: UInt

    init(_ value: UInt) { self.value = value }
    var hashValue: Int { return Int(bitPattern: value) }
    static func ==(left: TestHashable, right: TestHashable) -> Bool { return left.value == right.value }
}

class HashingTests: XCTestCase {
    func test_FNV1a_combinedHashes_empty() {
        XCTAssertEqual(combinedHashes(), Int.baseHash)
    }

    func test_FNV1a_sampleData() {
        // Data from http://www.isthe.com/chongo/tech/comp/fnv/
        let testData: [UInt: Int]
        switch MemoryLayout<Int>.size {
        case 4:
            testData = [
                0xc43124cc: 0,
                0xcb9f4de0: 0
            ]
        case 8:
            testData = [
                0x3608874253b96bd5: 0
            ]
        default:
            preconditionFailure("Unsupported size for Int")
        }

        for (value, expected) in testData {
            XCTAssertEqual(Int.baseHash.mixed(withHash: Int(bitPattern: value)), expected)
            XCTAssertEqual(Int.baseHash.mixed(with: TestHashable(value)), expected)
            XCTAssertEqual(combinedHashes(Int(bitPattern: value)), expected)
        }
    }

    func test_FNV1a_fullTestData() {
        // Test data from http://www.isthe.com/chongo/src/fnv/test_fnv.c
        let input: [(UInt32, UInt64, Data)] = [
            (0x811c9dc5, 0xcbf29ce484222325, TEST("")),
            (0xe40c292c, 0xaf63dc4c8601ec8c, TEST("a")),
            (0xe70c2de5, 0xaf63df4c8601f1a5, TEST("b")),
            (0xe60c2c52, 0xaf63de4c8601eff2, TEST("c")),
            (0xe10c2473, 0xaf63d94c8601e773, TEST("d")),
            (0xe00c22e0, 0xaf63d84c8601e5c0, TEST("e")),
            (0xe30c2799, 0xaf63db4c8601ead9, TEST("f")),
            (0x6222e842, 0x08985907b541d342, TEST("fo")),
            (0xa9f37ed7, 0xdcb27518fed9d577, TEST("foo")),
            (0x3f5076ef, 0xdd120e790c2512af, TEST("foob")),
            (0x39aaa18a, 0xcac165afa2fef40a, TEST("fooba")),
            (0xbf9cf968, 0x85944171f73967e8, TEST("foobar")),
            (0x050c5d1f, 0xaf63bd4c8601b7df, TEST0("")),
            (0x2b24d044, 0x089be207b544f1e4, TEST0("a")),
            (0x9d2c3f7f, 0x08a61407b54d9b5f, TEST0("b")),
            (0x7729c516, 0x08a2ae07b54ab836, TEST0("c")),
            (0xb91d6109, 0x0891b007b53c4869, TEST0("d")),
            (0x931ae6a0, 0x088e4a07b5396540, TEST0("e")),
            (0x052255db, 0x08987c07b5420ebb, TEST0("f")),
            (0xbef39fe6, 0xdcb28a18fed9f926, TEST0("fo")),
            (0x6150ac75, 0xdd1270790c25b935, TEST0("foo")),
            (0x9aab3a3d, 0xcac146afa2febf5d, TEST0("foob")),
            (0x519c4c3e, 0x8593d371f738acfe, TEST0("fooba")),
            (0x0c1c9eb8, 0x34531ca7168b8f38, TEST0("foobar")),
            (0x5f299f4e, 0x08a25607b54a22ae, TEST("ch")),
            (0xef8580f3, 0xf5faf0190cf90df3, TEST("cho")),
            (0xac297727, 0xf27397910b3221c7, TEST("chon")),
            (0x4546b9c0, 0x2c8c2b76062f22e0, TEST("chong")),
            (0xbd564e7d, 0xe150688c8217b8fd, TEST("chongo")),
            (0x6bdd5c67, 0xf35a83c10e4f1f87, TEST("chongo ")),
            (0xdd77ed30, 0xd1edd10b507344d0, TEST("chongo w")),
            (0xf4ca9683, 0x2a5ee739b3ddb8c3, TEST("chongo wa")),
            (0x4aeb9bd0, 0xdcfb970ca1c0d310, TEST("chongo was")),
            (0xe0e67ad0, 0x4054da76daa6da90, TEST("chongo was ")),
            (0xc2d32fa8, 0xf70a2ff589861368, TEST("chongo was h")),
            (0x7f743fb7, 0x4c628b38aed25f17, TEST("chongo was he")),
            (0x6900631f, 0x9dd1f6510f78189f, TEST("chongo was her")),
            (0xc59c990e, 0xa3de85bd491270ce, TEST("chongo was here")),
            (0x448524fd, 0x858e2fa32a55e61d, TEST("chongo was here!")),
            (0xd49930d5, 0x46810940eff5f915, TEST("chongo was here!\n")),
            (0x1c85c7ca, 0xf5fadd190cf8edaa, TEST0("ch")),
            (0x0229fe89, 0xf273ed910b32b3e9, TEST0("cho")),
            (0x2c469265, 0x2c8c5276062f6525, TEST0("chon")),
            (0xce566940, 0xe150b98c821842a0, TEST0("chong")),
            (0x8bdd8ec7, 0xf35aa3c10e4f55e7, TEST0("chongo")),
            (0x34787625, 0xd1ed680b50729265, TEST0("chongo ")),
            (0xd3ca6290, 0x2a5f0639b3dded70, TEST0("chongo w")),
            (0xddeaf039, 0xdcfbaa0ca1c0f359, TEST0("chongo wa")),
            (0xc0e64870, 0x4054ba76daa6a430, TEST0("chongo was")),
            (0xdad35570, 0xf709c7f5898562b0, TEST0("chongo was ")),
            (0x5a740578, 0x4c62e638aed2f9b8, TEST0("chongo was h")),
            (0x5b004d15, 0x9dd1a8510f779415, TEST0("chongo was he")),
            (0x6a9c09cd, 0xa3de2abd4911d62d, TEST0("chongo was her")),
            (0x2384f10a, 0x858e0ea32a55ae0a, TEST0("chongo was here")),
            (0xda993a47, 0x46810f40eff60347, TEST0("chongo was here!")),
            (0x8227df4f, 0xc33bce57bef63eaf, TEST0("chongo was here!\n")),
            (0x4c298165, 0x08a24307b54a0265, TEST("cu")),
            (0xfc563735, 0xf5b9fd190cc18d15, TEST("cur")),
            (0x8cb91483, 0x4c968290ace35703, TEST("curd")),
            (0x775bf5d0, 0x07174bd5c64d9350, TEST("curds")),
            (0xd5c428d0, 0x5a294c3ff5d18750, TEST("curds ")),
            (0x34cc0ea3, 0x05b3c1aeb308b843, TEST("curds a")),
            (0xea3b4cb7, 0xb92a48da37d0f477, TEST("curds an")),
            (0x8e59f029, 0x73cdddccd80ebc49, TEST("curds and")),
            (0x2094de2b, 0xd58c4c13210a266b, TEST("curds and ")),
            (0xa65a0ad4, 0xe78b6081243ec194, TEST("curds and w")),
            (0x9bbee5f4, 0xb096f77096a39f34, TEST("curds and wh")),
            (0xbe836343, 0xb425c54ff807b6a3, TEST("curds and whe")),
            (0x22d5344e, 0x23e520e2751bb46e, TEST("curds and whey")),
            (0x19a1470c, 0x1a0b44ccfe1385ec, TEST("curds and whey\n")),
            (0x4a56b1ff, 0xf5ba4b190cc2119f, TEST0("cu")),
            (0x70b8e86f, 0x4c962690ace2baaf, TEST0("cur")),
            (0x0a5b4a39, 0x0716ded5c64cda19, TEST0("curd")),
            (0xb5c3f670, 0x5a292c3ff5d150f0, TEST0("curds")),
            (0x53cc3f70, 0x05b3e0aeb308ecf0, TEST0("curds ")),
            (0xc03b0a99, 0xb92a5eda37d119d9, TEST0("curds a")),
            (0x7259c415, 0x73ce41ccd80f6635, TEST0("curds an")),
            (0x4095108b, 0xd58c2c132109f00b, TEST0("curds and")),
            (0x7559bdb1, 0xe78baf81243f47d1, TEST0("curds and ")),
            (0xb3bf0bbc, 0xb0968f7096a2ee7c, TEST0("curds and w")),
            (0x2183ff1c, 0xb425a84ff807855c, TEST0("curds and wh")),
            (0x2bd54279, 0x23e4e9e2751b56f9, TEST0("curds and whe")),
            (0x23a156ca, 0x1a0b4eccfe1396ea, TEST0("curds and whey")),
            (0x64e2d7e4, 0x54abd453bb2c9004, TEST0("curds and whey\n")),
            (0x683af69a, 0x08ba5f07b55ec3da, TEST("hi")),
            (0xaed2346e, 0x337354193006cb6e, TEST0("hi")),
            (0x4f9f2cab, 0xa430d84680aabd0b, TEST("hello")),
            (0x02935131, 0xa9bc8acca21f39b1, TEST0("hello")),
            (0xc48fb86d, 0x6961196491cc682d, TEST([0xff, 0x00, 0x00, 0x01])),
            (0x2269f369, 0xad2bb1774799dfe9, TEST([0x01, 0x00, 0x00, 0xff])),
            (0xc18fb3b4, 0x6961166491cc6314, TEST([0xff, 0x00, 0x00, 0x02])),
            (0x50ef1236, 0x8d1bb3904a3b1236, TEST([0x02, 0x00, 0x00, 0xff])),
            (0xc28fb547, 0x6961176491cc64c7, TEST([0xff, 0x00, 0x00, 0x03])),
            (0x96c3bf47, 0xed205d87f40434c7, TEST([0x03, 0x00, 0x00, 0xff])),
            (0xbf8fb08e, 0x6961146491cc5fae, TEST([0xff, 0x00, 0x00, 0x04])),
            (0xf3e4d49c, 0xcd3baf5e44f8ad9c, TEST([0x04, 0x00, 0x00, 0xff])),
            (0x32179058, 0xe3b36596127cd6d8, TEST([0x40, 0x51, 0x4e, 0x44])),
            (0x280bfee6, 0xf77f1072c8e8a646, TEST([0x44, 0x4e, 0x51, 0x40])),
            (0x30178d32, 0xe3b36396127cd372, TEST([0x40, 0x51, 0x4e, 0x4a])),
            (0x21addaf8, 0x6067dce9932ad458, TEST([0x4a, 0x4e, 0x51, 0x40])),
            (0x4217a988, 0xe3b37596127cf208, TEST([0x40, 0x51, 0x4e, 0x54])),
            (0x772633d6, 0x4b7b10fa9fe83936, TEST([0x54, 0x4e, 0x51, 0x40])),
            (0x08a3d11e, 0xaabafe7104d914be, TEST("127.0.0.1")),
            (0xb7e2323a, 0xf4d3180b3cde3eda, TEST0("127.0.0.1")),
            (0x07a3cf8b, 0xaabafd7104d9130b, TEST("127.0.0.2")),
            (0x91dfb7d1, 0xf4cfb20b3cdb5bb1, TEST0("127.0.0.2")),
            (0x06a3cdf8, 0xaabafc7104d91158, TEST("127.0.0.3")),
            (0x6bdd3d68, 0xf4cc4c0b3cd87888, TEST0("127.0.0.3")),
            (0x1d5636a7, 0xe729bac5d2a8d3a7, TEST("64.81.78.68")),
            (0xd5b808e5, 0x74bc0524f4dfa4c5, TEST0("64.81.78.68")),
            (0x1353e852, 0xe72630c5d2a5b352, TEST("64.81.78.74")),
            (0xbf16b916, 0x6b983224ef8fb456, TEST0("64.81.78.74")),
            (0xa55b89ed, 0xe73042c5d2ae266d, TEST("64.81.78.84")),
            (0x3c1a2017, 0x8527e324fdeb4b37, TEST0("64.81.78.84")),
            (0x0588b13c, 0x0a83c86fee952abc, TEST("feedface")),
            (0xf22f0174, 0x7318523267779d74, TEST0("feedface")),
            (0xe83641e1, 0x3e66d3d56b8caca1, TEST("feedfacedaffdeed")),
            (0x6e69b533, 0x956694a5c0095593, TEST0("feedfacedaffdeed")),
            (0xf1760448, 0xcac54572bb1a6fc8, TEST("feedfacedeadbeef")),
            (0x64c8bd58, 0xa7a4c9f3edebf0d8, TEST0("feedfacedeadbeef")),
            (0x97b4ea23, 0x7829851fac17b143, TEST("line 1\nline 2\nline 3")),
            (0x9a4e92e6, 0x2c8f4c9af81bcf06, TEST("chongo <Landon Curt Noll> /\\../\\")),
            (0xcfb14012, 0xd34e31539740c732, TEST0("chongo <Landon Curt Noll> /\\../\\")),
            (0xf01b2511, 0x3605a2ac253d2db1, TEST("chongo (Landon Curt Noll) /\\../\\")),
            (0x0bbb59c3, 0x08c11b8346f4a3c3, TEST0("chongo (Landon Curt Noll) /\\../\\")),
            (0xce524afa, 0x6be396289ce8a6da, TEST("http://antwrp.gsfc.nasa.gov/apod/astropix.html")),
            (0xdd16ef45, 0xd9b957fb7fe794c5, TEST("http://en.wikipedia.org/wiki/Fowler_Noll_Vo_hash")),
            (0x60648bb3, 0x05be33da04560a93, TEST("http://epod.usra.edu/")),
            (0x7fa4bcfc, 0x0957f1577ba9747c, TEST("http://exoplanet.eu/")),
            (0x5053ae17, 0xda2cc3acc24fba57, TEST("http://hvo.wr.usgs.gov/cam3/")),
            (0xc9302890, 0x74136f185b29e7f0, TEST("http://hvo.wr.usgs.gov/cams/HMcam/")),
            (0x956ded32, 0xb2f2b4590edb93b2, TEST("http://hvo.wr.usgs.gov/kilauea/update/deformation.html")),
            (0x9136db84, 0xb3608fce8b86ae04, TEST("http://hvo.wr.usgs.gov/kilauea/update/images.html")),
            (0xdf9d3323, 0x4a3a865079359063, TEST("http://hvo.wr.usgs.gov/kilauea/update/maps.html")),
            (0x32bb6cd0, 0x5b3a7ef496880a50, TEST("http://hvo.wr.usgs.gov/volcanowatch/current_issue.html")),
            (0xc8f8385b, 0x48fae3163854c23b, TEST("http://neo.jpl.nasa.gov/risk/")),
            (0xeb08bfba, 0x07aaa640476e0b9a, TEST("http://norvig.com/21-days.html")),
            (0x62cc8e3d, 0x2f653656383a687d, TEST("http://primes.utm.edu/curios/home.php")),
            (0xc3e20f5c, 0xa1031f8e7599d79c, TEST("http://slashdot.org/")),
            (0x39e97f17, 0xa31908178ff92477, TEST("http://tux.wr.usgs.gov/Maps/155.25-19.5.html")),
            (0x7837b203, 0x097edf3c14c3fb83, TEST("http://volcano.wr.usgs.gov/kilaueastatus.php")),
            (0x319e877b, 0xb51ca83feaa0971b, TEST("http://www.avo.alaska.edu/activity/Redoubt.php")),
            (0xd3e63f89, 0xdd3c0d96d784f2e9, TEST("http://www.dilbert.com/fast/")),
            (0x29b50b38, 0x86cd26a9ea767d78, TEST("http://www.fourmilab.ch/gravitation/orbits/")),
            (0x5ed678b8, 0xe6b215ff54a30c18, TEST("http://www.fpoa.net/")),
            (0xb0d5b793, 0xec5b06a1c5531093, TEST("http://www.ioccc.org/index.html")),
            (0x52450be5, 0x45665a929f9ec5e5, TEST("http://www.isthe.com/cgi-bin/number.cgi")),
            (0xfa72d767, 0x8c7609b4a9f10907, TEST("http://www.isthe.com/chongo/bio.html")),
            (0x95066709, 0x89aac3a491f0d729, TEST("http://www.isthe.com/chongo/index.html")),
            (0x7f52e123, 0x32ce6b26e0f4a403, TEST("http://www.isthe.com/chongo/src/calc/lucas-calc")),
            (0x76966481, 0x614ab44e02b53e01, TEST("http://www.isthe.com/chongo/tech/astro/venus2004.html")),
            (0x063258b0, 0xfa6472eb6eef3290, TEST("http://www.isthe.com/chongo/tech/astro/vita.html")),
            (0x2ded6e8a, 0x9e5d75eb1948eb6a, TEST("http://www.isthe.com/chongo/tech/comp/c/expert.html")),
            (0xb07d7c52, 0xb6d12ad4a8671852, TEST("http://www.isthe.com/chongo/tech/comp/calc/index.html")),
            (0xd0c71b71, 0x88826f56eba07af1, TEST("http://www.isthe.com/chongo/tech/comp/fnv/index.html")),
            (0xf684f1bd, 0x44535bf2645bc0fd, TEST("http://www.isthe.com/chongo/tech/math/number/howhigh.html")),
            (0x868ecfa8, 0x169388ffc21e3728, TEST("http://www.isthe.com/chongo/tech/math/number/number.html")),
            (0xf794f684, 0xf68aac9e396d8224, TEST("http://www.isthe.com/chongo/tech/math/prime/mersenne.html")),
            (0xd19701c3, 0x8e87d7e7472b3883, TEST("http://www.isthe.com/chongo/tech/math/prime/mersenne.html#largest")),
            (0x346e171e, 0x295c26caa8b423de, TEST("http://www.lavarnd.org/cgi-bin/corpspeak.cgi")),
            (0x91f8f676, 0x322c814292e72176, TEST("http://www.lavarnd.org/cgi-bin/haiku.cgi")),
            (0x0bf58848, 0x8a06550eb8af7268, TEST("http://www.lavarnd.org/cgi-bin/rand-none.cgi")),
            (0x6317b6d1, 0xef86d60e661bcf71, TEST("http://www.lavarnd.org/cgi-bin/randdist.cgi")),
            (0xafad4c54, 0x9e5426c87f30ee54, TEST("http://www.lavarnd.org/index.html")),
            (0x0f25681e, 0xf1ea8aa826fd047e, TEST("http://www.lavarnd.org/what/nist-test.html")),
            (0x91b18d49, 0x0babaf9a642cb769, TEST("http://www.macosxhints.com/")),
            (0x7d61c12e, 0x4b3341d4068d012e, TEST("http://www.mellis.com/")),
            (0x5147d25c, 0xd15605cbc30a335c, TEST("http://www.nature.nps.gov/air/webcams/parks/havoso2alert/havoalert.cfm")),
            (0x9a8b6805, 0x5b21060aed8412e5, TEST("http://www.nature.nps.gov/air/webcams/parks/havoso2alert/timelines_24.cfm")),
            (0x4cd2a447, 0x45e2cda1ce6f4227, TEST("http://www.paulnoll.com/")),
            (0x1e549b14, 0x50ae3745033ad7d4, TEST("http://www.pepysdiary.com/")),
            (0x2fe1b574, 0xaa4588ced46bf414, TEST("http://www.sciencenews.org/index/home/activity/view")),
            (0xcf0cd31e, 0xc1b0056c4a95467e, TEST("http://www.skyandtelescope.com/")),
            (0x6c471669, 0x56576a71de8b4089, TEST("http://www.sput.nl/~rob/sirius.html")),
            (0x0e5eef1e, 0xbf20965fa6dc927e, TEST("http://www.systemexperts.com/")),
            (0x2bed3602, 0x569f8383c2040882, TEST("http://www.tq-international.com/phpBB3/index.php")),
            (0xb26249e0, 0xe1e772fba08feca0, TEST("http://www.travelquesttours.com/index.htm")),
            (0x2c9b86a4, 0x4ced94af97138ac4, TEST("http://www.wunderground.com/global/stations/89606.html")),
            (0xe415e2bb, 0xc4112ffb337a82fb, repeated(10, TEST("21701"))),
            (0x18a98d1d, 0xd64a4fd41de38b7d, repeated(10, TEST("M21701"))),
            (0xb7df8b7b, 0x4cfc32329edebcbb, repeated(10, TEST("2^21701-1"))),
            (0x241e9075, 0x0803564445050395, repeated(10, TEST([0x54, 0xc5]))),
            (0x063f70dd, 0xaa1574ecf4642ffd, repeated(10, TEST([0xc5, 0x54]))),
            (0x0295aed9, 0x694bc4e54cc315f9, repeated(10, TEST("23209"))),
            (0x56a7f781, 0xa3d7cb273b011721, repeated(10, TEST("M23209"))),
            (0x253bc645, 0x577c2f8b6115bfa5, repeated(10, TEST("2^23209-1"))),
            (0x46610921, 0xb7ec8c1a769fb4c1, repeated(10, TEST([0x5a, 0xa9]))),
            (0x7c1577f9, 0x5d5cfce63359ab19, repeated(10, TEST([0xa9, 0x5a]))),
            (0x512b2851, 0x33b96c3cd65b5f71, repeated(10, TEST("391581216093"))),
            (0x76823999, 0xd845097780602bb9, repeated(10, TEST("391581*2^216093-1"))),
            (0xc0586935, 0x84d47645d02da3d5, repeated(10, TEST([0x05, 0xf9, 0x9d, 0x03, 0x4c, 0x81]))),
            (0xf3415c85, 0x83544f33b58773a5, repeated(10, TEST("FEDCBA9876543210"))),
            (0x0ae4ff65, 0x9175cbb2160836c5, repeated(10, TEST([0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10]))),
            (0x58b79725, 0xc71b3bc175e72bc5, repeated(10, TEST("EFCDAB8967452301"))),
            (0xdea43aa5, 0x636806ac222ec985, repeated(10, TEST([0xef, 0xcd, 0xab, 0x89, 0x67, 0x45, 0x23, 0x01]))),
            (0x2bb3be35, 0xb6ef0e6950f52ed5, repeated(10, TEST("0123456789ABCDEF"))),
            (0xea777a45, 0xead3d8a0f3dfdaa5, repeated(10, TEST([0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]))),
            (0x8f21c305, 0x922908fe9a861ba5, repeated(10, TEST("1032547698BADCFE"))),
            (0x5c9d0865, 0x6d4821de275fd5c5, repeated(10, TEST([0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe]))),
            (0xfa823dd5, 0x1fe3fce62bd816b5, repeated(500, TEST([0x00]))),
            (0x21a27271, 0xc23e9fccd6f70591, repeated(500, TEST([0x07]))),
            (0x83c5c6d5, 0xc1af12bdfe16b5b5, repeated(500, TEST("~"))),
            (0x813b0881, 0x39e9f18f2f85e221, repeated(500, TEST([0x7f]))),
        ]

        for (h32, h64, data) in input {
            let actual = data.withUnsafeBytes { p in
                Int.baseHash.mixed(with: UnsafeRawBufferPointer(start: p, count: data.count))
            }
            switch MemoryLayout<Int>.size {
            case 4:
                XCTAssertEqual(actual, Int(bitPattern: UInt(h32)))
            case 8:
                XCTAssertEqual(actual, Int(bitPattern: UInt(h64)))
            default:
                XCTFail("Unsupported size for Int")
            }
        }
    }
}
