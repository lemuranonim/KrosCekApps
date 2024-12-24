import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'vegetative_screen.dart';
import 'generative_screen.dart';
import 'training_screen.dart';
import 'absen_log_screen.dart';
import 'issue_screen.dart';
import 'login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'activity_screen.dart';  // Import halaman aktivitas
import 'config_manager.dart';

class PspScreen extends StatefulWidget {
  const PspScreen({super.key});

  @override
  PspScreenState createState() => PspScreenState();
}

class PspScreenState extends State<PspScreen> {
  int _selectedIndex = 0;
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...'; // Tambahkan variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  List<String> fieldSPVList = ['Region 4', 'Region 5'];
  List<String> faList = [];
  List<String> qaSPVList = [];
  List<String> seasonList = ['DS24'];
  String? selectedFieldSPV;
  String? selectedFA;
  String? selectedQA;
  String? selectedSeason;

  // Simpan season ke SharedPreferences
  Future<void> _saveSeasonPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedSeason', selectedSeason ?? '');
  }

  // Fetch season dari SharedPreferences
  Future<void> _loadSeasonPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSeason = prefs.getString('selectedSeason');
    });
  }

  // Map untuk ID document di Firestore
  final Map<String, String> regionDocumentIds = {
    'Region 4': 'region 4',
    'Region 5': 'region 5',
  };

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
    _fetchPspEmail();
    _fetchPspData();
    _loadPspEmail(); // Panggil fungsi untuk mengambil email pengguna
    _loadSeasonPreference(); // Load season preference on init
  }

  // Fungsi untuk mengambil email dan nama dari SharedPreferences
  Future<void> _fetchPspData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  // Fungsi untuk mengambil email dari SharedPreferences
  Future<void> _fetchPspEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
    });
  }

  // Fungsi untuk mengambil email pengguna dari SharedPreferences
  Future<void> _loadPspEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Email tidak ditemukan';
    });
  }

  // Fungsi untuk menyimpan pilihan QA SPV dan District ke SharedPreferences
  Future<void> _saveFilterPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedQA', selectedQA ?? ''); // Beri nilai default jika null
    await prefs.setString('selectedFA', selectedFA ?? ''); // Beri nilai default jika null
  }

  Future<void> _fetchQASPV(String selectedRegion) async {
    // Cek apakah data QA SPV sudah ada di SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedQASPV = prefs.getString('qaSPV_$selectedRegion');

    if (cachedQASPV != null) {
      // Jika ada cache, gunakan data yang ada
      setState(() {
        qaSPVList = List<String>.from(jsonDecode(cachedQASPV));
        selectedQA = null; // Reset pilihan QA agar pengguna memilih ulang
      });
      return;
    }

    // Jika tidak ada cache, ambil data dari Firestore
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    String? documentId = regionDocumentIds[selectedRegion];

    if (documentId == null) {
      setState(() {
        qaSPVList = [];
      });
      return;
    }

    try {
      DocumentReference regionDoc = firestore.collection('regions').doc(documentId);
      DocumentSnapshot docSnapshot = await regionDoc.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        qaSPVList = (data['qa_spv'] as Map<String, dynamic>).keys.toList();

        // Simpan data ke SharedPreferences untuk cache
        await prefs.setString('qaSPV_$selectedRegion', jsonEncode(qaSPVList));

        setState(() {
          selectedQA = null; // Reset QA SPV agar pengguna harus memilih manual
        });
      }
    } catch (error) {
      setState(() {
        qaSPVList = [];
      });
    }
  }

  Future<void> _fetchDistricts(String selectedRegion, String selectedQASPV) async {
    // Cek cache untuk data district berdasarkan region dan QA SPV
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedDistricts = prefs.getString('districts_${selectedRegion}_$selectedQASPV');

    if (cachedDistricts != null) {
      setState(() {
        faList = List<String>.from(jsonDecode(cachedDistricts));
      });
      return;
    }

    // Ambil data dari Firestore jika cache tidak ada
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    String documentId = regionDocumentIds[selectedRegion]!;

    try {
      DocumentReference regionDoc = firestore.collection('regions').doc(documentId);
      DocumentSnapshot docSnapshot = await regionDoc.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        List<String> districts = List<String>.from(data['qa_spv'][selectedQASPV]['districts']);

        // Simpan hasil ke SharedPreferences untuk cache
        await prefs.setString('districts_${selectedRegion}_$selectedQASPV', jsonEncode(districts));

        setState(() {
          faList = districts;
        });
      }
    } catch (error) {
      // Handle error
    }
  }

  Future<void> _fetchAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  // Fungsi refresh tanpa parameter
  Future<void> _refreshData() async {
    if (selectedFieldSPV != null) {
      await _fetchQASPV(selectedFieldSPV!);
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Tampilkan dialog konfirmasi logout dan tunggu hasilnya
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Konfirmasi Medal"),
          content: const Text("Menopo panjenengan yakin badhe medal?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Return false
              },
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true
              },
              child: const Text("Medal"),
            ),
          ],
        );
      },
    );

    // Jika pengguna memilih 'Medal', lakukan logout
    if (confirmLogout == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  // Fungsi untuk menavigasi ke halaman lain
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // Fungsi untuk menampilkan popup menu
  void _showPopupMenu() {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(25.0, 600.0, 25.0, 100.0),
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.engineering, color: Colors.green),
            title: const Text('Training'),
            onTap: () {
              Navigator.of(context).pop();
              _navigateTo(
                context,
                TrainingScreen(
                  onSave: (updatedData) {
                    setState(() {
                      // Lakukan sesuatu dengan updatedData setelah disimpan
                    });
                  },
                ),
              );
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.list, color: Colors.green),
            title: const Text('Absen Log'),
            onTap: () {
              Navigator.of(context).pop();
              _navigateTo(context, const AbsenLogScreen());
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.green),
            title: const Text('Issue'),
            onTap: () {
              Navigator.of(context).pop();
              if (selectedFA != null) {
                _navigateTo(
                  context,
                  IssueScreen(
                    selectedFA: selectedFA!,
                    onSave: (updatedIssue) {
                      setState(() {
                        // Lakukan sesuatu dengan updatedIssue setelah disimpan
                      });
                    },
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('District belum dipilih!')),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0
            ? const Text('PSP Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : const Text('Aktivitas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _selectedIndex == 1
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
        )
            : null,
      ),
      drawer: _selectedIndex == 0
          ? Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.green,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/logo.png'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Version $_appVersion',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.green),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      )
          : null,
      body: IndexedStack(
        index: _selectedIndex, // Pastikan index selalu valid
        children: [
          LiquidPullToRefresh(
            onRefresh: _refreshData,
            color: Colors.green,
            backgroundColor: Colors.white,
            height: 150,
            showChildOpacityTransition: false,
            child: _buildPspContent(context),
          ),
          const SizedBox.shrink(),
          const ActivityScreen(),
        ],
      ),
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Colors.green,
        items: const [
          TabItem(icon: Icons.home, title: 'Beranda'),  // Tab Beranda
          TabItem(icon: Icons.add, title: ''),  // Tab '+' untuk memunculkan popup
          TabItem(icon: Icons.restore, title: 'Aktivitas'),  // Tab Aktivitas
        ],
        initialActiveIndex: _selectedIndex,  // Menentukan tab awal yang aktif
        onTap: (int index) {
          if (index == 1) {  // Jika tab dengan ikon '+' ditekan
            _showPopupMenu();  // Memunculkan popup menu
          } else {
            setState(() {
              _selectedIndex = index;  // Hanya ubah state dan halaman untuk tab selain `+`
            });
          }
        },
      ),
    );
  }

  Widget _buildPspContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.10 * 255).toInt()),
                spreadRadius: 3,  // Spread of the shadow
                blurRadius: 2,  // Blur radius of the shadow
                offset: const Offset(0, 3),  // Shadow offset position
              ),
            ],
          ),
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),  // Rounded corners for the card
            ),
            elevation: 0,  // Turn off default shadow of the card
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TyperAnimatedTextKit for "Sugeng Rawuh Lur" and "Monggo dipun Kroscek!"
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TyperAnimatedText(
                          'Sugeng Rawuh Lur...',  // First part of the text
                          textStyle: const TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,  // Green text color
                          ),
                          textAlign: TextAlign.center,
                          speed: const Duration(milliseconds: 250),  // Typing speed
                        ),
                        TyperAnimatedText(
                          'Monggo dipun Kroscek!',  // Second part of the text
                          textStyle: const TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,  // Green text color
                          ),
                          textAlign: TextAlign.center,
                          speed: const Duration(milliseconds: 250),  // Typing speed
                        ),
                      ],
                      totalRepeatCount: 1,  // Animation runs once
                      pause: const Duration(milliseconds: 1000),  // Pause between the two animations
                      displayFullTextOnTap: true,  // Display full text on tap
                      stopPauseOnTap: true,  // Stop the pause on tap
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dropdown untuk memilih Region
                  DropdownButtonFormField<String>(
                    value: selectedFieldSPV,
                    hint: const Text("Pilih Regionmu!"),
                    items: fieldSPVList.map((spv) {
                      return DropdownMenuItem<String>(
                        value: spv,
                        child: Text(spv),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedFieldSPV = value; // Simpan pilihan Region
                        selectedQA = null; // Reset pilihan QA SPV
                        selectedFA = null; // Reset pilihan District
                        selectedSeason = null;
                        faList.clear(); // Kosongkan daftar district
                      });
                      await _fetchQASPV(value!); // Ambil QA SPV berdasarkan Region yang dipilih
                    },
                    style: const TextStyle(
                      color: Colors.black,  // Change text color
                      fontSize: 16.0,  // Change text size
                    ),
                    decoration: InputDecoration(
                      labelText: 'Field Region',
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Change border color
                        borderRadius: BorderRadius.circular(8.0),  // Optional: round the corners
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Change focused border color
                        borderRadius: BorderRadius.circular(8.0),  // Optional: round the corners
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey, width: 2.0),  // Default border color
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Dropdown untuk memilih QA SPV
                  if (selectedFieldSPV != null && qaSPVList.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedQA,
                      hint: const Text("Pilih QA SPV!"),
                      items: qaSPVList.map((qa) {
                        return DropdownMenuItem<String>(
                          value: qa,
                          child: Text(qa),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setState(() {
                          selectedQA = value; // Simpan pilihan QA SPV
                          selectedFA = null; // Reset pilihan District
                          selectedSeason = null;
                        });
                        await _fetchDistricts(selectedFieldSPV!, value!); // Ambil district berdasarkan QA SPV
                        await _saveFilterPreferences();  // Panggil fungsi ini untuk menyimpan data ke SharedPreferences
                      },
                      style: const TextStyle(
                        color: Colors.black,  // Change text color
                        fontSize: 16.0,  // Change text size
                      ),
                      decoration: InputDecoration(
                        labelText: 'QA SPV',
                        filled: true,
                        fillColor: Colors.white,  // Background color of the dropdown field
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Green border when not focused
                          borderRadius: BorderRadius.circular(8.0),  // Optional: round the corners
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Green border when focused
                          borderRadius: BorderRadius.circular(8.0),  // Optional: round the corners
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey, width: 2.0),  // Default border
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Dropdown untuk memilih District
                  if (selectedQA != null && faList.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedFA,
                      hint: const Text("Pilih District!"),
                      items: faList.map((fa) {
                        return DropdownMenuItem<String>(
                          value: fa,
                          child: Text(fa),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedFA = value; // Simpan pilihan District
                          selectedSeason = null;
                        });
                      },
                      style: const TextStyle(
                        color: Colors.black,  // Change text color
                        fontSize: 16.0,  // Change text size
                      ),
                      decoration: InputDecoration(
                        labelText: 'District',
                        filled: true,
                        fillColor: Colors.white,  // Background color for the dropdown
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Green border when not focused
                          borderRadius: BorderRadius.circular(8.0),  // Rounded corners
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Green border when focused
                          borderRadius: BorderRadius.circular(8.0),  // Rounded corners
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey, width: 2.0),  // Default border color
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Dropdown untuk memilih Season
                  if (selectedFA != null && seasonList.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedSeason,
                      hint: const Text("Pilih Season!"),
                      items: seasonList.map((season) {
                        return DropdownMenuItem<String>(
                          value: season,
                          child: Text(season),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSeason = value; // Simpan pilihan Season
                          _saveSeasonPreference(); // Simpan pilihan season
                        });
                      },
                      style: const TextStyle(
                        color: Colors.black,  // Change text color
                        fontSize: 16.0,  // Change text size
                      ),
                      decoration: InputDecoration(
                        labelText: 'Season',
                        filled: true,
                        fillColor: Colors.white,  // Background color for the dropdown
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Green border when not focused
                          borderRadius: BorderRadius.circular(8.0),  // Rounded corners
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.green, width: 2.0),  // Green border when focused
                          borderRadius: BorderRadius.circular(8.0),  // Rounded corners
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey, width: 2.0),  // Default border color
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Box untuk menampilkan hasil
                  if (selectedQA != null || selectedFA != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(top: 10.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha((0.5 * 255).toInt()),
                            spreadRadius: 2,
                            blurRadius: 7,
                            offset: const Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tampilkan QA SPV yang dipilih
                          if (selectedQA != null) ...[
                            RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'QA SPV: ',
                                    style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),  // Bold only "QA SPV"
                                  ),
                                  TextSpan(
                                    text: selectedQA,  // Non-bold for the value
                                    style: const TextStyle(fontSize: 16, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Tampilkan District yang dipilih
                          if (selectedFA != null) ...[
                            RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'District: ',
                                    style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),  // Bold only "District"
                                  ),
                                  TextSpan(
                                    text: selectedFA,  // Non-bold for the value
                                    style: const TextStyle(fontSize: 16, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Tampilkan Season yang dipilih
                          if (selectedSeason != null) ...[
                            RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Season: ',
                                    style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),  // Bold only "District"
                                  ),
                                  TextSpan(
                                    text: selectedSeason,  // Non-bold for the value
                                    style: const TextStyle(fontSize: 16, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],

                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'FASE INSPEKSI PSP',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            buildCategoryItem(
              context,
              'assets/vegetative.png',
              'Vegetative',
              selectedFieldSPV != null
                  ? ConfigManager.getSpreadsheetId(selectedFieldSPV!) // Ambil spreadsheetId
                  : null,
            ),
            buildCategoryItem(
              context,
              'assets/generative.png',
              'Generative',
              selectedFieldSPV != null
                  ? ConfigManager.getSpreadsheetId(selectedFieldSPV!) // Ambil spreadsheetId
                  : null,
            ),
          ],
        ),
      ],
    );
  }


  Widget buildCategoryItem(
      BuildContext context,
      String imagePath,
      String label,
      String? spreadsheetId, // Tambahkan spreadsheetId sebagai parameter
      ) {
    return GestureDetector(
      onTap: () {
        if (spreadsheetId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Spreadsheet ID tidak ditemukan!')),
          );
          return;
        }

        Widget targetScreen;
        switch (label) {
          case 'Vegetative':
            targetScreen = VegetativeScreen(
              spreadsheetId: spreadsheetId,
              selectedQA: selectedQA,
              selectedSeason: selectedSeason,
              seasonList: seasonList,
            );
            break;
          case 'Generative':
            targetScreen = GenerativeScreen(
              spreadsheetId: spreadsheetId,
              seasonList: seasonList,
            ); // Kirim spreadsheetId
            break;
          default:
            return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(55.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.10 * 255).toInt()),
              spreadRadius: 3,
              blurRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(55.0),
          ),
          elevation: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(imagePath, height: 60, width: 60, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
