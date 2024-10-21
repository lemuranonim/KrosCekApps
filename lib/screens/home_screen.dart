import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vegetative_screen.dart';
import 'generative_screen.dart';
import 'pre_harvest_screen.dart';
import 'harvest_screen.dart';
import 'training_screen.dart';
import 'absen_log_screen.dart';
import 'issue_screen.dart';
import 'login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'activity_screen.dart';  // Import halaman aktivitas


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();  // Changed to public class
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...'; // Tambahkan variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  List<String> fieldSPVList = ['Region 4', 'Region 5'];
  List<String> faList = [];
  List<String> qaSPVList = [];
  String? selectedFieldSPV;
  String? selectedFA;
  String? selectedQA;

  // Map untuk ID document di Firestore
  final Map<String, String> regionDocumentIds = {
    'Region 4': 'region 4',
    'Region 5': 'region 5',
  };

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
    _fetchUserEmail();
    _fetchUserData();
    _loadUserEmail(); // Panggil fungsi untuk mengambil email pengguna
  }

  // Fungsi untuk mengambil email dan nama dari SharedPreferences
  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  // Fungsi untuk mengambil email dari SharedPreferences
  Future<void> _fetchUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
    });
  }

  // Fungsi untuk mengambil email pengguna dari SharedPreferences
  Future<void> _loadUserEmail() async {
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
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Cek apakah dokumen ID ada di map
    String? documentId = regionDocumentIds[selectedRegion];
    if (documentId == null) {
      setState(() {
        qaSPVList = [];
      });
      return; // Jika tidak ada dokumen, keluar dari fungsi
    }

    try {
      DocumentReference regionDoc = firestore.collection('regions').doc(documentId);
      DocumentSnapshot docSnapshot = await regionDoc.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        List<String> qaSPVList = (data['qa_spv'] as Map<String, dynamic>).keys.toList();

        setState(() {
          this.qaSPVList = qaSPVList;
          selectedQA = null; // Reset QA SPV agar pengguna harus memilih manual
        });
      }
    } catch (error) {
      setState(() {
        qaSPVList = []; // Jika error, kosongkan list
      });
    }
  }

  Future<void> _fetchDistricts(String selectedRegion, String selectedQASPV) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Dapatkan document ID dari region yang dipilih
    String documentId = regionDocumentIds[selectedRegion]!;

    try {
      DocumentReference regionDoc = firestore.collection('regions').doc(documentId);
      DocumentSnapshot docSnapshot = await regionDoc.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        List<String> districts = List<String>.from(data['qa_spv'][selectedQASPV]['districts']);

        setState(() {
          faList = districts;
        });
      }
    } catch (error) {
      // Hapus perintah print
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
    // Simpan context sebelum operasi async dimulai
    final navigator = Navigator.of(context);

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
      await prefs.remove('isLoggedIn');
      await prefs.remove('userRole');

      // Gunakan navigator yang sudah disimpan untuk navigasi
      _navigateToLoginScreen(navigator);
    }
  }

// Fungsi terpisah untuk menangani navigasi
  void _navigateToLoginScreen(NavigatorState navigator) {
    navigator.pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
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
              _navigateTo(context, const TrainingScreen());
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.list, color: Colors.green),
            title: const Text('Absen Log'),
            onTap: () {
              Navigator.of(context).pop();
              _navigateTo(context, AbsenLogScreen(userName: userEmail));
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
                _navigateTo(context, IssueScreen(selectedFA: selectedFA!));
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
            ? const Text('KrosCekApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
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
            child: _buildHomeContent(context),
          ),
          const ActivityScreen(),
        ],
      ),
      bottomNavigationBar: ConvexAppBar(
        backgroundColor: Colors.green,
        items: const [
          TabItem(icon: Icons.home, title: 'Beranda'),  // Tab Beranda
          TabItem(icon: Icons.local_activity, title: 'Aktivitas'),  // Tab Aktivitas
          TabItem(icon: Icons.add, title: ''),  // Tab '+' untuk memunculkan popup
        ],
        initialActiveIndex: _selectedIndex,  // Menentukan tab awal yang aktif
        onTap: (int index) {
          if (index == 2) {  // Jika tab dengan ikon '+' ditekan
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

  Widget _buildHomeContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),  // Shadow color with opacity
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
                            color: Colors.grey.withOpacity(0.5),
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
          'FASE INSPEKSI',
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
              'assets/vegetative.png',  // Image asset path
              'Vegetative',
              const VegetativeScreen(),
            ),
            buildCategoryItem(
              context,
              'assets/generative.png',  // Image asset path
              'Generative',
              const GenerativeScreen(),
            ),
            buildCategoryItem(
              context,
              'assets/preharvest.png',  // Image asset path
              'Pre-Harvest',
              const PreHarvestScreen(),
            ),
            buildCategoryItem(
              context,
              'assets/harvest.png',  // Image asset path
              'Harvest',
              const HarvestScreen(),
            ),
          ],
        ),
      ],
    );
  }


  Widget buildCategoryItem(BuildContext context, String imagePath, String label, Widget screen) {
    return GestureDetector(
      onTap: () {
        if (selectedFA == null) {
          // Jika District belum dipilih, tampilkan pesan error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('District belum dipilih!')),
          );
          return; // Hentikan eksekusi jika District belum dipilih
        }

        // Arahkan ke halaman yang sesuai berdasarkan label tombol
        if (label == 'Vegetative') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VegetativeScreen(
                selectedDistrict: selectedFA, // Kirimkan district yang dipilih
              ),
            ),
          );
        } else if (label == 'Generative') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GenerativeScreen(
                selectedDistrict: selectedFA, // Kirimkan district yang dipilih
              ),
            ),
          );
        } else if (label == 'Pre-Harvest') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreHarvestScreen(
                selectedDistrict: selectedFA, // Kirimkan district yang dipilih
              ),
            ),
          );
        } else if (label == 'Harvest') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HarvestScreen(
                selectedDistrict: selectedFA, // Kirimkan district yang dipilih
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(55.0),  // Rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),  // Shadow color with transparency
              spreadRadius: 3,  // Spread radius of the shadow
              blurRadius: 2,  // Blur radius of the shadow
              offset: const Offset(0, 3),  // Offset of the shadow
            ),
          ],
        ),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(55.0),  // Rounded corners for the card
          ),
          elevation: 0,  // Disable Card's built-in shadow since we use custom shadow
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  imagePath,
                  height: 60,  // Adjust image size
                  width: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,  // Make the text bold
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
