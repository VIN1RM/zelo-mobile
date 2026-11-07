import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, writeBatch, setLogLevel } from 'firebase/firestore';
setLogLevel('silent');

let env;
const uid='rider-a';
const email='rider@example.com';
const now=Date.now();
const wrap=(id,data,revision=1,deleted=false)=>({id,userId:uid,revision,deleted,data,updatedAt:now});
const contact=(id,priority,phone)=>wrap(id,{id,name:'Contato',priority,phone,email:null});
const db=()=>env.authenticatedContext(uid,{email,email_verified:true,auth_time:Math.floor(Date.now()/1000)}).firestore();
const path=(slot)=>`users/${uid}/emergency_contacts/${slot}`;
before(async()=>{
  env=await initializeTestEnvironment({projectId:'demo-zelo',firestore:{host:'127.0.0.1',port:8080,rules:await readFile(new URL('../../firestore.rules',import.meta.url),'utf8')}});
});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();});
test('requires authentication, verified email and matching owner',async()=>{
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),`users/${uid}`)));
  await assertFails(getDoc(doc(env.authenticatedContext(uid,{email_verified:false}).firestore(),`users/${uid}`)));
  await assertFails(getDoc(doc(env.authenticatedContext('other',{email_verified:true}).firestore(),`users/${uid}`)));
});
test('limits slots and rejects missing channels',async()=>{
  await assertFails(setDoc(doc(db(),path('4')),contact('a',1,'+5511999990001')));
  await assertFails(setDoc(doc(db(),path('1')),contact('a',1,null)));
  await assertSucceeds(setDoc(doc(db(),path('1')),contact('a',1,'+5511999990001')));
});
test('rejects duplicate priority, phone and email across slots',async()=>{
  await setDoc(doc(db(),path('1')),contact('a',1,'+5511999990001'));
  await assertFails(setDoc(doc(db(),path('2')),contact('b',1,'+5511999990002')));
  await assertFails(setDoc(doc(db(),path('2')),contact('b',2,'+5511999990001')));
});
test('atomic reorder preserves unique priorities',async()=>{
  const database=db();
  await setDoc(doc(database,path('1')),contact('a',1,'+5511999990001'));
  await setDoc(doc(database,path('2')),contact('b',2,'+5511999990002'));
  const batch=writeBatch(database);
  batch.set(doc(database,path('1')),{...contact('a',2,'+5511999990001'),revision:2});
  batch.set(doc(database,path('2')),{...contact('b',1,'+5511999990002'),revision:2});
  await assertSucceeds(batch.commit());
});
test('tombstones reject stale resurrection',async()=>{
  const database=db();const ref=doc(database,path('1'));const value=contact('a',1,'+5511999990001');
  await setDoc(ref,value);
  await setDoc(ref,{...value,revision:2,deleted:true});
  await assertFails(setDoc(ref,{...value,revision:3}));
});
test('incident origin and resolved outcome are immutable',async()=>{
  const database=db();const ref=doc(database,`users/${uid}/incidents/i`);
  const data={id:'i',type:'MANUAL_SOS',sessionId:null,occurredAt:now,deadline:null,outcome:'HELP_REQUESTED',condition:'NEEDS_HELP',preserved:true,position:null,location:null};
  await assertSucceeds(setDoc(ref,wrap('i',data)));
  await assertFails(setDoc(ref,wrap('i',{...data,outcome:'CANCELLED'},2)));
  await assertFails(setDoc(ref,wrap('i',{...data,type:'POSSIBLE_ACCIDENT'},2)));
  await assertSucceeds(setDoc(ref,wrap('i',{...data,condition:'SAFE'},2)));
});
test('does not permit photos, local paths or private notes in cloud payload',async()=>{
  const value=contact('a',1,'+5511999990001');
  await assertFails(setDoc(doc(db(),path('1')),{...value,data:{...value.data,localPath:'/private/photo.jpg'}}));
});
test('account deletion fence blocks even an otherwise valid existing token',async()=>{
  const database=db();
  await assertSucceeds(setDoc(doc(database,`account_deletions/${uid}`),{userId:uid,phase:'REQUESTED',createdAt:now}));
  await assertFails(setDoc(doc(database,path('1')),contact('a',1,'+5511999990001')));
  await assertSucceeds(updateDoc(doc(database,`account_deletions/${uid}`),{phase:'DATA_REMOVED'}));
});
