using Cysharp.Threading.Tasks;
using DG.Tweening;
using System;
using UnityEngine;
using Random = UnityEngine.Random;


public class SetBlendShape : MonoBehaviour {
	int browUpIndex = 0;
	int browAngryIndex = 1;
	int browSleepyIndex = 2;
	int eyeCloseIndex = 3;
	int eyeSmileIndex = 4;
	int rightEyeSmileIndex = 5;
	int leftEyeSmileIndex = 6;
	int rightEyeCloseIndex = 7;
	int leftEyeCloseIndex = 8;
	int bigEyesIndex = 9;
	int aIndex = 10;
	int iIndex = 11;
	int uIndex = 12;
	int eIndex = 13;
	int oIndex = 14;
	int horizonMouthSmallIndex = 15;
	int horizonMouthBigIndex = 16;
	int mouthSurpriseIndex = 17;
	int mouthHappyIndex = 18;
	int mouthAngerIndex = 19;
	int mouthSadIndex = 20;
	int mouthSmileIndex = 21;
	int mouthTeethSmileIndex = 22;
	int mouthTeethAngerIndex = 23;

	public Animator animator; //外部赋值或者在Awake里获取都行
	private AnimationClip[] clips = null;
	public SkinnedMeshRenderer skinnedMeshRenderer;
	public void SetBlendShapeValue( int Index, float value, float duration ) {
		float currentValue = skinnedMeshRenderer.GetBlendShapeWeight( Index );
		float aimValue = value;
		DOTween.To( () => currentValue, ( x ) => {
			skinnedMeshRenderer.SetBlendShapeWeight( Index, x );
		}, aimValue, duration ).SetEase( Ease.OutCubic );
	}

	public void SetHappy() {
		SetBlendShapeValue( eyeSmileIndex, 90f, 0.5f );
		SetBlendShapeValue( mouthHappyIndex, 50f, 0.5f );
		SetBlendShapeValue( mouthTeethSmileIndex, 30f, 0.5f );
	}

	public void SetDull() {
		SetBlendShapeValue( browUpIndex, 48f, 0.5f );
		SetBlendShapeValue( mouthHappyIndex, 23.5f, 0.5f );
		SetBlendShapeValue( horizonMouthSmallIndex, 24f, 0.5f );
		SetBlendShapeValue( eyeSmileIndex, 12f, 0.5f );
	}

	public void SetBlink( float duration ) {
		for( int i = 4; i < 10; i++ ) {
			if( skinnedMeshRenderer.GetBlendShapeWeight( i ) > 20f ) {
				return;
			}
		}

		float currentRightValue = skinnedMeshRenderer.GetBlendShapeWeight( rightEyeCloseIndex );
		DOTween.To( () => currentRightValue, ( x ) => {
			skinnedMeshRenderer.SetBlendShapeWeight( rightEyeCloseIndex, x );
		}, 100, duration ).SetEase( Ease.OutCubic ).onComplete += () => {
			DOTween.To( () => 100, ( x ) => {
				skinnedMeshRenderer.SetBlendShapeWeight( rightEyeCloseIndex, x );
			}, currentRightValue, duration ).SetEase( Ease.OutCubic );
		};

		float currentLeftValue = skinnedMeshRenderer.GetBlendShapeWeight( leftEyeCloseIndex );
		DOTween.To( () => currentLeftValue, ( x ) => {
			skinnedMeshRenderer.SetBlendShapeWeight( leftEyeCloseIndex, x );
		}, 100, duration ).SetEase( Ease.OutCubic ).onComplete += () => {
			DOTween.To( () => 100, ( x ) => {
				skinnedMeshRenderer.SetBlendShapeWeight( leftEyeCloseIndex, x );
			}, currentLeftValue, duration ).SetEase( Ease.OutCubic );
		};
	}

	async UniTaskVoid BlinkEachFewSeconds( float duration, float interval ) {
		while( true ) {
			SetBlink( duration );
			await UniTask.Delay( TimeSpan.FromSeconds( Random.Range( interval,interval*2 )) );
		}
	}

	public void SetInit() {
		for( int i = 0; i < skinnedMeshRenderer.sharedMesh.blendShapeCount; i++ ) {
			if( i == browUpIndex ) {
				if( skinnedMeshRenderer.GetBlendShapeWeight( browUpIndex ) > 30f || skinnedMeshRenderer.GetBlendShapeWeight( browUpIndex ) < 20f ) {
					SetBlendShapeValue( browUpIndex, 23.5f, 0.5f );
				}
			} else if( i == browSleepyIndex ) {
				if( skinnedMeshRenderer.GetBlendShapeWeight( browSleepyIndex ) > 30f || skinnedMeshRenderer.GetBlendShapeWeight( browUpIndex ) < 20f ) {
					SetBlendShapeValue( browUpIndex, 23.5f, 0.5f );
				}
			} else if( i == eyeSmileIndex ) {
				if( skinnedMeshRenderer.GetBlendShapeWeight( eyeSmileIndex ) > 15f || skinnedMeshRenderer.GetBlendShapeWeight( browUpIndex ) < 5f ) {
					SetBlendShapeValue( eyeSmileIndex, 10f, 0.5f );
				}
			} else if( i == mouthSmileIndex ) {
				if( skinnedMeshRenderer.GetBlendShapeWeight( mouthSmileIndex ) > 35f || skinnedMeshRenderer.GetBlendShapeWeight( browUpIndex ) < 25f ) {
					SetBlendShapeValue( mouthSmileIndex, 30f, 0.5f );
				}
			} else {
				SetBlendShapeValue( i, 0f, 0.5f );
			}
		}
	}


	void Awake() {
		BlinkEachFewSeconds( 0.6f, 4f ).Forget();
	}

	public void Start() {

		// SetSmile() ;
		// SetHappy() ;
	}

}