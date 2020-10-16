import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat/const.dart';
import 'package:flutter_chat/home_screen.dart';
import 'package:flutter_chat/widgets/loading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final String title;

  const LoginScreen({Key key, this.title}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences sharedPreferences;

  bool isLoading = false;
  bool isLoggedIn = false;
  User currentUser;

  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    setState(() {
      isLoading = true;
    });

    sharedPreferences = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn)
      Get.to(HomeScreen(currentUserId: sharedPreferences.getString("id")));

    setState(() {
      isLoading = false;
    });
  }

  Future<Null> handleSignIn() async {
    sharedPreferences = await SharedPreferences.getInstance();

    setState(() {
      isLoading = true;
    });

    GoogleSignInAccount googleUser = await googleSignIn.signIn();
    GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    User firebaseUser =
        (await firebaseAuth.signInWithCredential(credential)).user;

    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('id', isEqualTo: firebaseUser.uid)
          .get();
      final List<DocumentSnapshot> documents = result.docs;
      if (documents.length == 0) {
        // Update data to server if new user
        FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
          "nickname": firebaseUser.displayName,
          "photoUrl": firebaseUser.photoURL,
          "id": firebaseUser.uid,
          "createdAt": DateTime.now().millisecondsSinceEpoch.toString(),
          "chattingWith": null,
        });

        // Write data to local
        currentUser = firebaseUser;
        await sharedPreferences.setString("id", currentUser.uid);
        await sharedPreferences.setString("nickname", currentUser.displayName);
        await sharedPreferences.setString("photoUrl", currentUser.photoURL);
      } else {
        // Write data to local
        await sharedPreferences.setString("id", documents[0].data()["id"]);
        await sharedPreferences.setString(
            "nickname", documents[0].data()["nickname"]);
        await sharedPreferences.setString(
            "photoUrl", documents[0].data()["photoUrl"]);
        await sharedPreferences.setString(
            "aboutMe", documents[0].data()["aboutMe"]);
      }
      Fluttertoast.showToast(msg: "Sign in success");
      setState(() {
        isLoading = false;
      });

      Get.to(HomeScreen(currentUserId: firebaseUser.uid));
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: FlatButton(
              onPressed: handleSignIn,
              child: Text(
                "SIGN IN WITH GOOGLE",
                style: TextStyle(fontSize: 16),
              ),
              color: Color(0xffdd4b39),
              highlightColor: Color(0xffff7f7f),
              splashColor: Colors.transparent,
              textColor: Colors.white,
              padding: EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0),
            ),

            // Loading
          ),
          Positioned(
            child: isLoading ? const Loading() : Container(),
          ),
        ],
      ),
    );
  }
}
