import { getCompanies, getCities } from '@/lib/db';


export default async function CompaniesPage({ searchParams }) {
   // Получение параметров из URL
   const search = searchParams?.search || '';
   const city = searchParams?.city || '';


   // Получение данных на сервере
   const companies = getCompanies(search, city);
   const cities = getCities();


   return (
       <div className="p-6 max-w-6xl mx-auto">
           <h1 className="text-2xl font-bold mb-6">Компании</h1>


           {/* Форма поиска и фильтрации */}
           <form method="GET" className="flex gap-4 mb-6 flex-wrap">
               <input
                   type="text"
                   name="search"
                   placeholder="Поиск по названию..."
                   defaultValue={search}
                   className="border px-4 py-2 rounded flex-1 min-w-[200px]"
               />
               <select
                   name="city"
                   defaultValue={city}
                   className="border px-4 py-2 rounded"
               >
                   <option value="">Все города</option>
                   {cities.map((c) => (
                       <option key={c} value={c}>
                           {c}
                       </option>
                   ))}
               </select>
               <button
                   type="submit"
                   className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700"
               >
                   Применить
               </button>
               <a
                   href="/companies"
                   className="bg-gray-200 text-gray-800 px-6 py-2 rounded hover:bg-gray-300 inline-flex items-center"
               >
                   Сбросить
               </a>
           </form>


           {/* Таблица */}
           <div className="overflow-x-auto">
               <table className="min-w-full bg-white border">
                   <thead className="bg-gray-100">
                   <tr>
                       <th className="border px-4 py-2 text-left">Название</th>
                       <th className="border px-4 py-2 text-left">Категория</th>
                       <th className="border px-4 py-2 text-left">Город</th>
                       <th className="border px-4 py-2 text-left">Рейтинг</th>
                       <th className="border px-4 py-2 text-left">Отзывы</th>
                   </tr>
                   </thead>
                   <tbody>
                   {companies.length === 0 ? (
                       <tr>
                           <td colSpan="5" className="text-center py-8 text-gray-500">
                               Ничего не найдено
                           </td>
                       </tr>
                   ) : (
                       companies.map((company) => (
                           <tr key={company.id} className="hover:bg-gray-50">
                               <td className="border px-4 py-2">{company.name}</td>
                               <td className="border px-4 py-2">{company.category}</td>
                               <td className="border px-4 py-2">{company.city}</td>
                               <td className="border px-4 py-2">
                                   {company.rating ? company.rating.toFixed(1) : '—'}
                               </td>
                               <td className="border px-4 py-2">{company.reviews_count}</td>
                           </tr>
                       ))
                   )}
                   </tbody>
               </table>
           </div>
           <p className="mt-4 text-sm text-gray-500">
               Найдено компаний: {companies.length}
           </p>
       </div>
   );
}